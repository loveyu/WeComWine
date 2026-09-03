#!/usr/bin/env bash

set -Eeuo pipefail

readonly engine_root="/app/deepin-wine10-stable"
readonly overlay_root="/app/share/wecom-deepin/adapter/dlls"

# This package is intentionally a normal-mode runner.  The debugger binaries
# are also removed while the Flatpak is assembled, but reject explicit debug
# commands here as a second guard against accidentally triggering WeCom's risk
# controls.
case "${1:-}" in
    winedbg|winedbg.exe|*/winedbg|*/winedbg.exe|winegdb|*/winegdb|gdb|*/gdb)
        printf '该 Flatpak 禁止以调试模式运行企业微信。\n' >&2
        exit 64
        ;;
esac

export PATH="${engine_root}/bin:${PATH}"
export LD_LIBRARY_PATH="/app/lib/deepin-compat${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export WINEDLLPATH="${engine_root}/lib:${engine_root}/lib64"
export WINEPREDLL="${overlay_root}"
export ATTACH_FILE_DIALOG=1
export WINEPREFIX="${WINEPREFIX:-/var/data/wine-wecom-deepin}"
export WINE_WMCLASS="${WINE_WMCLASS:-com.qq.weixin.work.deepin}"
# Disable Wine diagnostic channels; this runner must remain in normal mode.
export WINEDEBUG="-all"

exec "${engine_root}/bin/wine" "$@"
