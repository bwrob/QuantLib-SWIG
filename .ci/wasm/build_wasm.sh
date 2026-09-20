#!/bin/bash
# Builds QuantLib and QuantLib-SWIG Python bindings for WebAssembly / Pyodide.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PYTHON_DIR="${REPO_DIR}/Python"

# Defaults
QL_SRC_DIR="${QL_SRC_DIR:-${REPO_DIR}/../QuantLib}"
BOOST_DIR="${BOOST_DIR:-$(brew --prefix boost 2>/dev/null || echo '/usr/local')}"
BUILD_JOBS="${BUILD_JOBS:-4}"

echo "=== Building QuantLib C++ for WebAssembly ==="
if [ ! -d "${QL_SRC_DIR}" ]; then
    echo "Error: QuantLib source directory not found at ${QL_SRC_DIR}"
    exit 1
fi

QL_BUILD_DIR="${QL_SRC_DIR}/build-wasm"
QL_INSTALL_DIR="${QL_BUILD_DIR}/install"

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

echo "=== Generating SWIG wrappers ==="
cd "${PYTHON_DIR}"
swig -python -c++ -outdir src/QuantLib -o src/QuantLib/quantlib_wrap.cpp ../SWIG/quantlib.i

echo "=== Building Python WASM Wheel with pyodide-build ==="
export QL_DIR="${QL_INSTALL_DIR}"
export INCLUDE="${BOOST_DIR}/include"

pyodide build --no-isolation --exports whole_archive

echo "=== Successfully built QuantLib WASM wheel in ${PYTHON_DIR}/dist/ ==="
