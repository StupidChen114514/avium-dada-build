#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$BASE/avium/out/target/product/dada"
ART="$BASE/artifacts"

mkdir -p "$ART"
shopt -s nullglob

echo "==> 输出目录: $OUT"

for z in "$OUT"/*.zip; do
    case "$z" in
        *target_files*) continue ;;
    esac
    cp -v "$z" "$ART/"
done

for img in boot init_boot vendor_boot dtbo vbmeta recovery super_empty; do
    [ -f "$OUT/$img.img" ] && cp -v "$OUT/$img.img" "$ART/"
done

if [ -d "$OUT/images" ]; then
    cp -rv "$OUT/images" "$ART/"
fi

cd "$ART"
sha256sum ./* > SHA256SUMS 2>/dev/null || true
echo "==> 产物列表"
ls -lh
