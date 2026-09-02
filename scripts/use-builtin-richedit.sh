#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/native-richedit.status"

if [[ ! -f "${WINEPREFIX_HOST}/system.reg" ]]; then
    printf '正式 Wine 前缀尚未初始化：%s\n' "${WINEPREFIX_HOST}" >&2
    exit 65
fi

# A previous native run may have replaced Wine's prefix stub and persisted a
# native,builtin registry override.  Restore both parts before launching the
# client; merely skipping the native installer would still load the old DLL.
WINEDEBUG_VALUE=-all flatpak_wine sh -c '
    builtin=/app/lib/wine/i386-windows/riched20.dll
    target="${WINEPREFIX}/drive_c/windows/syswow64/riched20.dll"

    test -r "${builtin}"
    install -m 0644 "${builtin}" "${target}"
    wine reg.exe delete "HKCU\Software\Wine\DllOverrides" \
        /v riched20 /f >/dev/null 2>&1 || true
    wineserver -k >/dev/null 2>&1 || true
    wineserver -w >/dev/null 2>&1 || true
'

write_status "${STATUS_FILE}" "builtin" \
    "prefix=${WINEPREFIX_HOST},reason=${1:-default}"
printf '%s using Wine builtin RichEdit prefix=%s reason=%s\n' \
    "$(date --iso-8601=seconds)" "${WINEPREFIX_HOST}" "${1:-default}"
