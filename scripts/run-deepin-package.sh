#!/usr/bin/env bash

set -Eeuo pipefail

/app/share/wecom-deepin/initialize-prefix.sh
/app/share/wecom-deepin/install-official-wecom.sh
WECOM_CEF_STANDALONE=1 \
WECOM_CEF_ROOT="${WINEPREFIX}/drive_c/Program Files (x86)/WXWork" \
WECOM_CEF_STATUS_FILE="${WINEPREFIX}/.cef-compat.status" \
    /app/share/wecom-deepin/patch-wecom-cef.sh
/app/bin/deepin-wine regedit /S \
    /app/share/wecom-deepin/adapter/wxworkweb.reg
exec /app/bin/deepin-wine \
    'C:\Program Files (x86)\WXWork\WXWork.exe' "$@"
