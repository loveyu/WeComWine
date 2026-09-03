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
# CEF's Windows ANGLE backends cannot create a reliable child-window surface
# under Wine: D3D11/D3D9 fail device creation and ANGLE OpenGL fails to set the
# Wine window's pixel format.  Keep WebView on Chromium's software-compositing
# path.  CEF already disables the renderer sandbox after its retry limit under
# Wine; request that final mode directly so the first renderers survive.
exec /app/bin/deepin-wine \
    'C:\Program Files (x86)\WXWork\WXWork.exe' \
    --disable-gpu \
    --disable-gpu-compositing \
    --no-sandbox \
    "$@"
