#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$BASE/avium"
BUILD_TYPE="${BUILD_TYPE:-userdebug}"

cd "$SRC"

export LC_ALL=C
export USE_CCACHE=1
export WITH_GMS="${WITH_GMS:-false}"
export CCACHE_DIR="$BASE/ccache"
export CCACHE_EXEC="$(command -v ccache)"
mkdir -p "$CCACHE_DIR"
"$CCACHE_EXEC" -M 60G >/dev/null 2>&1 || true

echo "==> 初始化构建环境"
source build/envsetup.sh

if [ "$WITH_GMS" = "true" ]; then
    if [ ! -d vendor/pixel/gms ] || [ ! -d vendor/pixel/clocks ] || [ ! -d vendor/pixel/sounds ]; then
        echo "ERROR: GMS 仓库缺失，请确认 local_manifests/pixel.xml 已同步。" >&2
        exit 1
    fi
    echo "==> GMS 已启用"
fi

echo "==> brunch dada $BUILD_TYPE"
brunch dada "$BUILD_TYPE" 2>&1 | tee "$BASE/build.log"

echo "==> 编译完成"
