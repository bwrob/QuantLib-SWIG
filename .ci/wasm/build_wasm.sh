#!/bin/bash
# Builds QuantLib and QuantLib-SWIG Python bindings for WebAssembly / Pyodide.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PYTHON_DIR="${REPO_DIR}/Python"

# Defaults
QL_SRC_DIR="${QL_SRC_DIR:-${REPO_DIR}/../QuantLib}"
if [ -z "${BOOST_DIR}" ]; then
    if [ -d "/usr/include/boost" ]; then
        BOOST_DIR="/usr"
    elif [ -d "/usr/local/include/boost" ]; then
        BOOST_DIR="/usr/local"
    elif command -v brew &>/dev/null; then
        BOOST_DIR="$(brew --prefix boost 2>/dev/null || echo '/usr/local')"
    else
        BOOST_DIR="/usr"
    fi
fi

# On Linux (e.g. Ubuntu/Debian), Boost is installed into /usr/include/boost.
# Passing -I/usr/include to Emscripten causes clang to look in host glibc headers
# (e.g. unistd.h, features.h) instead of Emscripten's musl libc sysroot, causing compilation failure.
# Isolate the boost/ directory so only Boost headers are exposed.
if [ "${BOOST_DIR}" = "/usr" ] || [ "${BOOST_DIR}" = "/usr/" ]; then
    ISOLATED_BOOST_DIR="/tmp/ql-boost-wasm"
    mkdir -p "${ISOLATED_BOOST_DIR}/include"
    ln -sfn /usr/include/boost "${ISOLATED_BOOST_DIR}/include/boost"
    BOOST_DIR="${ISOLATED_BOOST_DIR}"
fi

BUILD_JOBS="${BUILD_JOBS:-4}"
# Activate virtual environment if present and not already in one
if [ -z "${VIRTUAL_ENV}" ] && [ -f "${REPO_DIR}/.venv/bin/activate" ]; then
    source "${REPO_DIR}/.venv/bin/activate"
fi

# Detect emcmake if not in PATH
if ! command -v emcmake &>/dev/null; then
    EMSDK_EMCMAKE=$(find "$(python -c "from pyodide_build.common import default_xbuildenv_path; print(default_xbuildenv_path())" 2>/dev/null)" -name emcmake 2>/dev/null | head -n 1)
    if [ -n "${EMSDK_EMCMAKE}" ]; then
        export PATH="$(dirname "${EMSDK_EMCMAKE}"):$PATH"
    fi
fi

echo "Building QuantLib C++ for WebAssembly..."
if [ ! -d "${QL_SRC_DIR}" ]; then
    echo "Error: QuantLib source directory not found at ${QL_SRC_DIR}"
    exit 1
fi

QL_BUILD_DIR="${QL_BUILD_DIR:-${QL_SRC_DIR}/build-wasm}"
QL_INSTALL_DIR="${QL_INSTALL_DIR:-${QL_BUILD_DIR}/install}"

mkdir -p "${QL_BUILD_DIR}"
emcmake cmake -B "${QL_BUILD_DIR}" -S "${QL_SRC_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DQL_BUILD_EXAMPLES=OFF \
    -DQL_BUILD_TEST_SUITE=OFF \
    -DQL_BUILD_BENCHMARK=OFF \
    -DCMAKE_UNITY_BUILD=ON \
    -DCMAKE_UNITY_BUILD_BATCH_SIZE=16 \
    -DBoost_INCLUDE_DIR="${BOOST_DIR}/include" \
    -DCMAKE_INSTALL_PREFIX="${QL_INSTALL_DIR}" \
    -DCMAKE_CXX_FLAGS="-fexceptions -O3 -DNDEBUG"

cmake --build "${QL_BUILD_DIR}" --target install -j "${BUILD_JOBS}"

if command -v swig &>/dev/null; then
    echo "Generating SWIG wrappers..."
    cd "${PYTHON_DIR}"
    swig -python -c++ -outdir src/QuantLib -o src/QuantLib/quantlib_wrap.cpp ../SWIG/quantlib.i
elif [ -f "${PYTHON_DIR}/src/QuantLib/quantlib_wrap.cpp" ]; then
    echo "Using pre-existing SWIG wrappers"
    cd "${PYTHON_DIR}"
else
    echo "Error: SWIG wrapper not found at ${PYTHON_DIR}/src/QuantLib/quantlib_wrap.cpp and swig is not installed."
    exit 1
fi

echo "Building Python WASM wheel..."
export PATH="${QL_INSTALL_DIR}/bin:$PATH"
export CXXFLAGS="-I${BOOST_DIR}/include ${CXXFLAGS:-}"

pyodide build --no-isolation --exports whole_archive

# Ensure wheel is compatible with both Pyodide 0.27 (emscripten_3_1_58) and newer pyemscripten tags
for f in "${PYTHON_DIR}/dist"/*pyemscripten*.whl; do
    if [ -f "$f" ]; then
        em_whl=$(echo "$f" | sed -E 's/pyemscripten_[0-9]+_[0-9]+/emscripten_3_1_58/g')
        cp "$f" "$em_whl"
    fi
done

echo "Successfully built QuantLib WASM wheel in ${PYTHON_DIR}/dist/"
