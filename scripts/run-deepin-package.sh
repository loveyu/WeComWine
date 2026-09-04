#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/wecom-proxy-environment.sh"

export WINEPREFIX="${WINEPREFIX:-/var/data/wine-wecom-deepin}"
exec 9>"${WINEPREFIX}.launch.lock"
if ! flock -n 9; then
    printf '企业微信已在该 Deepin 前缀中运行，忽略重复启动。\n' >&2
    exit 0
fi

/app/share/wecom-deepin/initialize-prefix.sh
/app/share/wecom-deepin/install-official-wecom.sh
/app/share/wecom-deepin/migrate-prefix-to-wine10.sh
/app/share/wecom-deepin/configure-host-file-open.sh
/app/share/wecom-deepin/prepare-runtime.sh
WECOM_CEF_STANDALONE=1 \
WECOM_CEF_ROOT="${WINEPREFIX}/drive_c/Program Files (x86)/WXWork" \
WECOM_CEF_STATUS_FILE="${WINEPREFIX}/.cef-compat.status" \
    /app/share/wecom-deepin/patch-wecom-cef.sh
# Wine 11 with Chromium software rendering is the historically validated
# combination for both embedded pages and ShellExecute -> winebrowser ->
# xdg-desktop-portal URI handoff. Do not import Deepin Wine 10's renderer=gdi
# override here.
exec /app/bin/deepin-wine \
    'C:\Program Files (x86)\WXWork\WXWork.exe' \
    --disable-gpu \
    "$@"
