#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
HOST_OPEN="${PROJECT_DIR}/scripts/wecom-host-open.sh"

run_fallback() {
    HOME=/home/tester \
    FLATPAK_ID=io.github.loveyu.WeComWine.Deepin \
    WINEPREFIX=/var/data/wine-wecom-deepin \
    WECOM_GDBUS_COMMAND=/usr/bin/false \
    WECOM_XDG_OPEN_COMMAND=/usr/bin/printf \
        bash "${HOST_OPEN}" "$1"
}

c_result="$(run_fallback \
    'wecom-select:file:///C:/users/tester/Documents/WXWork/Cache/Image/%E9%A9%BE%E9%A9%B6%E8%AF%81.png')"
[[ "${c_result}" == \
    'file:///home/tester/.var/app/io.github.loveyu.WeComWine.Deepin/data/wine-wecom-deepin/drive_c/users/tester/Documents/WXWork/Cache/Image' ]]

z_result="$(run_fallback \
    'wecom-select:file:///Z:/run/user/1000/doc/abc123/report.zip')"
[[ "${z_result}" == 'file:///run/user/1000/doc/abc123' ]]

if run_fallback 'wecom-select:file:///D:/unsupported.txt' >/dev/null 2>&1; then
    printf '不支持的驱动器不应交给宿主文件管理器\n' >&2
    exit 1
fi

plain_result="$(run_fallback 'https://example.com/test')"
[[ "${plain_result}" == 'https://example.com/test' ]]
