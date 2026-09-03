#!/usr/bin/env bash

set -Eeuo pipefail

readonly prefix="${WINEPREFIX:-/var/data/wine-wecom-deepin}"
readonly adapter_root="/app/share/wecom-deepin/adapter"
readonly helper_gl_root="/app/share/wecom-deepin/helper/gl-wine"

install -d "${prefix}"

# This is the application-specific part of Deepin's CallPreRun routine.  The
# complete run_v4.sh cannot be used here: it assumes /opt paths, invokes DTK
# desktop UI and may replace a prefix based on Debian package state.
if [[ ! -f "${prefix}/.libglsoftware" && \
      ! -f "${prefix}/.libglhardware" ]]; then
    if /app/bin/deepin-wine "${adapter_root}/win32-test.exe" \
        >/dev/null 2>&1; then
        touch "${prefix}/.libglhardware"
    else
        touch "${prefix}/.libglsoftware"
    fi
fi

if [[ ! -f "${prefix}/.init_d3d" ]]; then
    if [[ -f "${prefix}/.libglhardware" ]] && \
       ! "${helper_gl_root}/gl-wine64" >/dev/null 2>&1; then
        /app/bin/deepin-wine regedit /S \
            "${helper_gl_root}/gdid3d.reg" >/dev/null 2>&1 || true
    fi
    touch "${prefix}/.init_d3d"
fi
