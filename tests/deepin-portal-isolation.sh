#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
BUILD_SCRIPT="${PROJECT_DIR}/scripts/build-deepin-wine-flatpak.sh"
PORTAL_BUILD_SCRIPT="${PROJECT_DIR}/scripts/build-deepin-wine10-portal.sh"
WRAPPER="${PROJECT_DIR}/scripts/deepin-wine-wrapper.sh"

grep -Fq 'readonly engine_root="/app/deepin-wine10-stable"' "${WRAPPER}"
grep -Fq 'export WINEPREDLL="${adapter_dll_root}"' "${WRAPPER}"
grep -Fq 'WECOM_DEEPIN_WINE10_PORTAL_BUILD' "${BUILD_SCRIPT}"
grep -Fq 'WECOM_DEEPIN_WINE10_PORTAL_BUILD' "${PORTAL_BUILD_SCRIPT}"
grep -Fq 'wine/source/10.x/wine-10.14.tar.xz' "${PORTAL_BUILD_SCRIPT}"

adapter_copy_line="$(grep -nF 'cp -a /run/wecom-adapter/. /app/share/wecom-deepin/adapter/' \
    "${BUILD_SCRIPT}" | cut -d: -f1)"
wine10_overlay_line="$(grep -nF '/run/wine10-portal-build/build32/dlls/comdlg32/i386-windows/comdlg32.dll' \
    "${BUILD_SCRIPT}" | tail -n 1 | cut -d: -f1)"
[[ -n "${adapter_copy_line}" ]]
[[ -n "${wine10_overlay_line}" ]]
(( wine10_overlay_line > adapter_copy_line ))

for destination in \
    /app/deepin-wine10-stable/lib/wine/i386-windows/comdlg32.dll \
    /app/deepin-wine10-stable/lib/wine/x86_64-windows/comdlg32.dll \
    /app/deepin-wine10-stable/lib/wine/x86_64-unix/comdlg32.so \
    /app/share/wecom-deepin/adapter/dlls/i386-windows/comdlg32.dll \
    /app/share/wecom-deepin/adapter/dlls/x86_64-windows/comdlg32.dll; do
    grep -Fq "${destination}" "${BUILD_SCRIPT}"
done
if grep -Fq '/app/deepin-wine10-stable/lib/wine/i386-unix/' "${BUILD_SCRIPT}"; then
    printf 'Deepin Wine 10 新 WoW64 不应安装传统 i386 Unix 模块。\n' >&2
    exit 1
fi

if rg -n 'wechat-devtools-wine-flatpak|alipay-devtools-wine-flatpak' \
    "${BUILD_SCRIPT}" "${PORTAL_BUILD_SCRIPT}"; then
    printf '企业微信构建脚本不得引用两个 Wine 11 开发者工具仓库。\n' >&2
    exit 1
fi
