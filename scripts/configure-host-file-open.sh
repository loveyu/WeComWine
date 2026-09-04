#!/usr/bin/env bash

set -Eeuo pipefail

: "${WINEPREFIX:?WINEPREFIX 未设置}"

readonly association_version="4"
readonly marker="${WINEPREFIX}/.host-file-open-associations"
readonly progid='WeCom.HostOpen'
readonly user_classes_key='HKCU\Software\Classes'
readonly machine_classes_key='HKLM\Software\Classes'
readonly open_command='"C:\windows\system32\winebrowser.exe" "%1"'
readonly browser_commands='/app/bin/wecom-host-open,xdg-open'

if [[ -f "${marker}" ]] && [[ "$(<"${marker}")" == "${association_version}" ]]; then
    exit 0
fi

# WeCom invokes ShellExecute when a received attachment is opened. The stock
# prefix only gives a few file types an open command, so Office files,
# archives and even images can fall through to Wine's Open With dialog.
# Route non-executable attachment formats through winebrowser; inside the
# Flatpak, xdg-open then hands the file to the desktop OpenURI portal.
#
# Wine 11's HKCR view in this prefix resolves duplicate extension keys from
# HKLM\Software\Classes before the matching HKCU value.  The stock prefix
# already registers image and archive MIME keys under HKLM, so writing only
# HKCU leaves ShellExecute on pngfile (or with no ProgID for zip).  This is a
# dedicated WeCom prefix, therefore install the effective association in the
# machine classes hive as well as the per-user hive.
# Version 1 accidentally escaped the shell variables after the registry path
# separator. Remove those literal keys before writing the corrected entries.
/app/bin/deepin-wine reg.exe delete 'HKCU\Software\Classes${progid}' /f \
    >/dev/null 2>&1 || true
/app/bin/deepin-wine reg.exe delete 'HKCU\Software\Classes${extension}' /f \
    >/dev/null 2>&1 || true

for classes_key in "${user_classes_key}" "${machine_classes_key}"; do
    /app/bin/deepin-wine reg.exe add \
        "${classes_key}\\${progid}" \
        /ve /t REG_SZ /d '宿主系统默认应用' /f >/dev/null
    /app/bin/deepin-wine reg.exe add \
        "${classes_key}\\${progid}\\shell\\open\\command" \
        /ve /t REG_SZ /d "${open_command}" /f >/dev/null
done
/app/bin/deepin-wine reg.exe add \
    'HKCU\Software\Wine\WineBrowser' \
    /v Browsers /t REG_SZ /d "${browser_commands}" /f >/dev/null

for extension in \
    .doc .docx .docm .dot .dotx \
    .xls .xlsx .xlsm .xlsb .csv \
    .ppt .pptx .pptm .pps .ppsx \
    .pdf .txt .rtf .md .odt .ods .odp .wps .et .dps \
    .zip .rar .7z .tar .gz .bz2 .xz \
    .jpg .jpeg .png .gif .bmp .webp .svg .tif .tiff \
    .mp3 .wav .ogg .flac .m4a \
    .mp4 .mkv .avi .mov .webm .wmv \
    .eml .ics .json .xml .html .htm; do
    for classes_key in "${user_classes_key}" "${machine_classes_key}"; do
        /app/bin/deepin-wine reg.exe add \
            "${classes_key}\\${extension}" \
            /ve /t REG_SZ /d "${progid}" /f >/dev/null
    done
done

/app/deepin-wine10-stable/bin/wineserver --wait
printf '%s\n' "${association_version}" > "${marker}"
