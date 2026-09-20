#!/bin/bash
set -e

echo "=== Running QuantLib WASM build & test in Ubuntu Docker ==="

export QL_SRC_DIR="/workspace/QuantLib"
export QL_BUILD_DIR="/tmp/ql-wasm-build"
export QL_INSTALL_DIR="/tmp/ql-wasm-install"
export BUILD_JOBS=$(nproc)

cd /workspace/QuantLib-SWIG

# Install npm dependencies for test suite if needed
if [ ! -d ".ci/wasm/node_modules" ]; then
    echo "Installing test runner dependencies..."
    cd .ci/wasm && npm install && cd ../..
fi

# Run the standard build script
bash .ci/wasm/build_wasm.sh

# Run the test suite
node .ci/wasm/test_wasm.mjs

echo "=== Successfully verified QuantLib WASM build on Ubuntu Linux! ==="
