#!/usr/bin/env bash

set -Eeuo pipefail

: "${WINEPREFIX:?WINEPREFIX 未设置}"

readonly version="5.0.10.6025"
readonly installer="/app/share/wecom-deepin/official/WeCom_${version}.exe"
readonly installer_sha256="f9b028420b84dda6888246516e8a1dddd3174eaeb3d8d930e8e04264a9cfa513"
readonly program="${WINEPREFIX}/drive_c/Program Files (x86)/WXWork/WXWork.exe"
readonly program_sha256="46fbd8d193e6c42aa9cac4b38cf857cd125127cb658129b7d166dee8f17d6db2"
readonly marker="${WINEPREFIX}/.wecom-official-version"

file_matches() {
    local path="$1"
    local expected_sha256="$2"

    [[ -f "${path}" ]] && \
        [[ "$(sha256sum "${path}" | awk '{print $1}')" == "${expected_sha256}" ]]
}

if [[ -f "${marker}" ]] && [[ "$(<"${marker}")" == "${version}" ]] && \
   file_matches "${program}" "${program_sha256}"; then
    exit 0
fi

if ! file_matches "${installer}" "${installer_sha256}"; then
    printf 'Flatpak 中腾讯官方企业微信 %s 安装包缺失或摘要不匹配。\n' \
        "${version}" >&2
    exit 65
fi

# A matching program can come from a completed install whose marker write was
# interrupted.  Repair the marker without needlessly reinstalling the client.
if file_matches "${program}" "${program_sha256}"; then
    printf '%s\n' "${version}" > "${marker}"
    exit 0
fi

printf '正在正常安装腾讯官方企业微信 %s，并保留 Deepin 兼容前缀。\n' "${version}"
/app/bin/deepin-wine "${installer}" /S
/app/deepin-wine10-stable/bin/wineserver --wait

if ! file_matches "${program}" "${program_sha256}"; then
    printf '腾讯官方企业微信 %s 安装后主程序摘要不匹配。\n' "${version}" >&2
    exit 65
fi

printf '%s\n' "${version}" > "${marker}"
