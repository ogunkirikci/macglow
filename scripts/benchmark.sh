#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
cd "$PROJECT_DIR"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export SDKROOT=$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
export CLANG_MODULE_CACHE_PATH=$PROJECT_DIR/Build/BenchmarkModuleCache
SWIFT=$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift

"$SWIFT" run --disable-sandbox -c release MacGlowBenchmark
