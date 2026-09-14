#!/usr/bin/env bash

set -Eeuo pipefail

: "${WINEPREFIX:?WINEPREFIX 未设置}"

readonly emoji_font_source="${WECOM_EMOJI_FONT_SOURCE:-/app/share/fonts/truetype/noto/NotoEmoji-wght.ttf}"
readonly emoji_font_name="NotoEmoji-wght.ttf"
readonly emoji_font_family="Noto Emoji"
readonly windows_fonts_dir="${WINEPREFIX}/drive_c/windows/Fonts"
readonly emoji_font_target="${windows_fonts_dir}/${emoji_font_name}"
readonly wine_command="${WECOM_WINE_COMMAND:-/app/bin/deepin-wine}"
readonly system_link_key='HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'

if [[ ! -f "${emoji_font_source}" ]]; then
    printf '缺少企业微信 emoji 轮廓字体：%s\n' "${emoji_font_source}" >&2
    exit 65
fi
if [[ ! -d "${windows_fonts_dir}" ]]; then
    printf 'Wine 字体目录不存在：%s\n' "${windows_fonts_dir}" >&2
    exit 65
fi
if [[ ! -x "${wine_command}" ]]; then
    printf 'Wine 命令不可执行：%s\n' "${wine_command}" >&2
    exit 69
fi

if [[ ! -f "${emoji_font_target}" ]] || \
   ! cmp -s "${emoji_font_source}" "${emoji_font_target}"; then
    install -m 0644 "${emoji_font_source}" "${emoji_font_target}"
fi

"${wine_command}" reg.exe add \
    'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
    /v "${emoji_font_family} (TrueType)" /t REG_SZ \
    /d "${emoji_font_name}" /f >/dev/null

# Wine adds Tahoma and its SystemLink children to every ordinary GDI font.
# Append the emoji face there because Deepin's UI families are replacements;
# Wine deliberately ignores a SystemLink value keyed by a replacement family.
system_link_output="$(
    "${wine_command}" reg.exe query "${system_link_key}" /v Tahoma 2>/dev/null || true
)"
existing_system_link="$(
    printf '%s\n' "${system_link_output}" | tr -d '\r' | \
        sed -n 's/^[[:space:]]*Tahoma[[:space:]]*REG_MULTI_SZ[[:space:]]*//p'
)"
emoji_system_link="${emoji_font_name},${emoji_font_family}"
case "${existing_system_link}" in
    *"${emoji_font_name}"*)
        merged_system_link="${existing_system_link}"
        ;;
    '')
        merged_system_link="${emoji_system_link}"
        ;;
    *)
        merged_system_link="${existing_system_link}\\0${emoji_system_link}"
        ;;
esac
"${wine_command}" reg.exe add "${system_link_key}" \
    /v Tahoma /t REG_MULTI_SZ /d "${merged_system_link}" /f >/dev/null

# Chromium and other components may explicitly request the Windows emoji
# family rather than relying on the UI font's SystemLink chain.
"${wine_command}" reg.exe add \
    'HKCU\Software\Wine\Fonts\Replacements' \
    /v 'Segoe UI Emoji' /t REG_SZ /d "${emoji_font_family}" /f >/dev/null
