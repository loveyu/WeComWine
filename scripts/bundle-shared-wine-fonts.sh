#!/usr/bin/env bash

set -Eeuo pipefail

RUNTIME_FILES="${1:?用法：bundle-shared-wine-fonts.sh RUNTIME_FILES}"
WINDOWS_FONTS="${SHARED_WINE_WINDOWS_FONTS:-/usr/share/fonts/win10-fonts}"
FONT_TARGET="${RUNTIME_FILES}/deepin-wine10-stable/share/wine/fonts"
MANIFEST="${RUNTIME_FILES}/share/shared-wine/fonts.sha256"

mkdir -p "${FONT_TARGET}" "$(dirname -- "${MANIFEST}")"
font_files=()
# 只收录桌面 UI、开发编辑器和常用文档字体，不复制 Windows 缓存或位图字体。
windows_patterns=(
    'arial*.ttf' 'calibri*.ttf' 'cambria*.ttf' 'cambria.ttc'
    'consola*.ttf' 'cour*.ttf' 'georgia*.ttf' 'times*.ttf'
    'tahoma*.ttf' 'verdana*.ttf' 'trebuc*.ttf' 'micross.ttf'
    'segoeui*.ttf' 'segui*.ttf' 'segmdl2.ttf' 'symbol.ttf'
    'webdings.ttf' 'wingding.ttf' 'marlett.ttf'
    'msyh*.ttc' 'simsun.ttc' 'simsunb.ttf' 'simhei.ttf'
    'simfang.ttf' 'simkai.ttf'
)
if [[ -d "${WINDOWS_FONTS}" ]]; then
    for pattern in "${windows_patterns[@]}"; do
        while IFS= read -r -d '' font; do
            font_files+=("${font}")
        done < <(find "${WINDOWS_FONTS}" -maxdepth 1 -type f -iname "${pattern}" -print0)
    done
fi
# 开源字体同时作为中文、拉丁文和数学符号回退；不依赖宿主字体的运行时可见性。
for font in \
    /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc \
    /usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc \
    /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf \
    /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf \
    /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf \
    /usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf; do
    [[ ! -f "${font}" ]] || font_files+=("${font}")
done
if [[ -n "${SHARED_WINE_EXTRA_FONTS:-}" ]]; then
    [[ -d "${SHARED_WINE_EXTRA_FONTS}" ]] || exit 66
    while IFS= read -r -d '' font; do
        font_files+=("${font}")
    done < <(find "${SHARED_WINE_EXTRA_FONTS}" -maxdepth 1 -type f \
        \( -iname '*.ttf' -o -iname '*.ttc' -o -iname '*.otf' \) -print0)
fi

if (( ${#font_files[@]} == 0 )); then
    printf '未找到可打包的公共字体。\n' >&2
    exit 66
fi
# Wine 会扫描自己的 fonts 目录，注册为系统字体，DirectWrite 也能按原始族名查找。
# 文件保存在扩展中，应用层和各 Wine 前缀均不需要另存一份。
for font in "${font_files[@]}"; do
    font_name="$(basename -- "${font}")"
    font_name="${font_name,,}"
    install -m 0644 "${font}" "${FONT_TARGET}/${font_name}"
done
(
    cd "${RUNTIME_FILES}"
    find deepin-wine10-stable/share/wine/fonts -maxdepth 1 -type f \
        -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
) > "${MANIFEST}"
printf '共享底层字体：%s 个文件，%s\n' \
    "$(wc -l < "${MANIFEST}")" "$(du -sh "${FONT_TARGET}" | cut -f1)"
