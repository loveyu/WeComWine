#!/usr/bin/env bash

set -Eeuo pipefail

export WINEPREFIX="${WINEPREFIX:-/var/data/wine-wecom-deepin}"
install -d "${WINEPREFIX}"
exec 9>"${WINEPREFIX}/.wecom-launch.lock"
if ! flock -n 9; then
    printf '企业微信已在该 Deepin 前缀中运行，忽略重复启动。\n' >&2
    exit 0
fi

/app/share/wecom-deepin/initialize-prefix.sh
/app/share/wecom-deepin/install-official-wecom.sh
/app/share/wecom-deepin/prepare-runtime.sh
WECOM_CEF_STANDALONE=1 \
WECOM_CEF_ROOT="${WINEPREFIX}/drive_c/Program Files (x86)/WXWork" \
WECOM_CEF_STATUS_FILE="${WINEPREFIX}/.cef-compat.status" \
    /app/share/wecom-deepin/patch-wecom-cef.sh
/app/bin/deepin-wine regedit /S \
    /app/share/wecom-deepin/adapter/wxworkweb.reg
exec /app/bin/deepin-wine \
    'C:\Program Files (x86)\WXWork\WXWork.exe' "$@"
