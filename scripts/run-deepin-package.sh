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
/app/share/wecom-deepin/migrate-prefix-to-wine10.sh
/app/share/wecom-deepin/configure-emoji-font.sh
/app/share/wecom-deepin/configure-host-file-open.sh
/app/share/wecom-deepin/prepare-runtime.sh
WECOM_CEF_STANDALONE=1 \
WECOM_CEF_ROOT="${WINEPREFIX}/drive_c/Program Files (x86)/WXWork" \
WECOM_CEF_STATUS_FILE="${WINEPREFIX}/.cef-compat.status" \
    /app/share/wecom-deepin/patch-wecom-cef.sh
# The stable baseline is the packaged 5.0.7 client with its complete Deepin
# Wine 10 engine. Keep Chromium on software rendering for the validated CEF
# fallback path.
exec /app/bin/deepin-wine \
    'C:\Program Files (x86)\WXWork\WXWork.exe' \
    --disable-gpu \
    "$@"
