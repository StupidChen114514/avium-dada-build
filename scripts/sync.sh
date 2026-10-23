#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$BASE/avium"
JOBS="${JOBS:-32}"

echo "==> 工作目录: $BASE"
echo "==> 源码目录: $SRC"

mkdir -p "$SRC"

# repo/ git 需要身份信息
git config --global user.name  "${GIT_USER_NAME:-cnb-build}"
git config --global user.email "${GIT_USER_EMAIL:-cnb-build@localhost}"
git config --global advice.detachedHead false

# 国内镜像：只重写 LineageOS 与 AOSP，AviumUI / dada-devel 仍走 GitHub
git config --global url."https://mirrors.tuna.tsinghua.edu.cn/git/lineageOS/LineageOS/".insteadOf "https://github.com/LineageOS/"
git config --global url."https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/".insteadOf "https://android.googlesource.com/"

cd "$SRC"

echo "==> repo init (AviumUI avium-16.2)"
repo init -u https://github.com/AviumUI/android_manifests -b avium-16.2 --git-lfs --depth=1

echo "==> 写入本地设备清单"
mkdir -p .repo/local_manifests
cp "$BASE/local_manifests/dada.xml" .repo/local_manifests/dada.xml

if [ "${WITH_GMS:-false}" = "true" ]; then
    echo "==> 启用 GMS：加入 Pixel 软件包清单"
    cp "$BASE/local_manifests/pixel.xml" .repo/local_manifests/pixel.xml
fi

echo "==> repo sync -j$JOBS"
run_sync() {
    repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags --retry-fetches=5
}

if ! run_sync; then
    echo "WARN: 镜像源同步失败，回退 GitHub / Google 源重试" >&2
    git config --global --unset-all url."https://mirrors.tuna.tsinghua.edu.cn/git/lineageOS/LineageOS/".insteadOf || true
    git config --global --unset-all url."https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/".insteadOf || true
    run_sync
fi

echo "==> 拉取 Git LFS 大文件"
for d in \
    vendor/xiaomi/dada \
    vendor/xiaomi/sm8750-common \
    vendor/xiaomi/dada-firmware \
    device/xiaomi/dada-kernel; do
    [ -d "$d/.git" ] || continue
    echo "--- lfs pull: $d"
    git -C "$d" lfs pull || echo "WARN: lfs pull 失败: $d"
done

echo "==> 合并 GMS 分卷文件"
if [ -d vendor/pixel ]; then
    find vendor/pixel -type f -name '*.part' | sed -E 's/\.[0-9]+\.part$//; s/\.part$//' | sort -u |
    while IFS= read -r target; do
        [ -n "$target" ] || continue
        if [ -f "$target.part" ]; then
            rm -f "$target"
            mv "$target.part" "$target"
            echo "merged: $target"
            continue
        fi
        parts="$(find "$(dirname "$target")" -maxdepth 1 -type f -name "$(basename "$target").*.part" | sort -V)"
        [ -n "$parts" ] || continue
        : > "$target"
        while IFS= read -r part; do
            cat "$part" >> "$target"
            rm -f "$part"
        done <<< "$parts"
        echo "merged: $target"
    done
fi

if grep -rl --include='*.img' --include='*.so' --include='*.apk' \
        'git-lfs.github.com/spec' \
        vendor/xiaomi device/xiaomi/dada-kernel 2>/dev/null | head -n 1 | grep -q .; then
    echo "ERROR: 仍存在 Git LFS 指针文件，请重新运行流水线或检查 GitHub LFS 限流。" >&2
    exit 1
fi

echo "==> 应用设备树补丁"
apply_patch() {
    local repo="$1" patch="$2"
    [ -d "$repo" ] || { echo "WARN: 缺少目录 $repo，跳过 $patch"; return 0; }
    if git -C "$repo" apply --check "$patch" 2>/dev/null; then
        git -C "$repo" apply "$patch"
        echo "applied: $patch"
    else
        echo "skip (已应用或不适用): $patch"
    fi
}

apply_patch frameworks/av       device/xiaomi/dada/patches/0001-frameworks_av-disable-jpeg-r-capability.patch
apply_patch packages/apps/Aperture device/xiaomi/dada/patches/0002-Aperture-disable-ultra-hdr-default.patch

# AviumUI 的 sepolicy 分支缺少 dada 的 system_server 属性权限，直接补齐（幂等）
SEPOLICY=device/lineage/sepolicy/common/private/system_server.te
if [ -f "$SEPOLICY" ] && ! grep -q 'set_prop(system_server, custom_version_prop)' "$SEPOLICY"; then
    printf '\n# Let system server set lineage settings version property\nset_prop(system_server, custom_version_prop)\n' >> "$SEPOLICY"
    echo "patched: $SEPOLICY"
fi

echo "==> 校验关键源码"
test -f device/xiaomi/dada/lineage_dada.mk
test -f device/xiaomi/sm8750-common/BoardConfigCommon.mk
test -f device/xiaomi/dada-kernel/kernel
test -f vendor/xiaomi/dada/dada-vendor.mk

echo "==> 源码准备完成"
du -sh . 2>/dev/null || true
