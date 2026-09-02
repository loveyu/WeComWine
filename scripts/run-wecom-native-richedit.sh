#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/native-richedit.status"

if [[ ! -f "${NATIVE_RICHEDIT_DLL_HOST}" ]]; then
    printf '缺少已配置的原生 RichEdit：%s\n' \
        "${NATIVE_RICHEDIT_DLL_HOST}" >&2
    exit 66
fi
actual_sha256="$(sha256sum "${NATIVE_RICHEDIT_DLL_HOST}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${NATIVE_RICHEDIT_SHA256}" ]]; then
    printf '原生 RichEdit 摘要不匹配：%s\n' "${actual_sha256}" >&2
    exit 65
fi
if [[ ! -f "${WINEPREFIX_HOST}/system.reg" ]]; then
    printf '正式 Wine 前缀尚未初始化：%s\n' "${WINEPREFIX_HOST}" >&2
    exit 65
fi
if [[ ! -d "${WINEPREFIX_HOST}/drive_c/users" ]]; then
    printf '正式 Wine 前缀缺少用户目录：%s\n' \
        "${WINEPREFIX_HOST}/drive_c/users" >&2
    exit 65
fi

# Keep the complete prefix writable.  WeCom's updater installs new versions
# below Program Files and updates prefix state; wrapping the whole prefix in a
# disposable overlay silently discarded those writes after every launch.
install -m 0644 "${NATIVE_RICHEDIT_DLL_HOST}" \
    "${WINEPREFIX_HOST}/drive_c/windows/syswow64/riched20.dll"

WINEDEBUG_VALUE=-all flatpak_wine sh -c '
    wine reg.exe add "HKCU\Software\Wine\DllOverrides" \
        /v riched20 /d "native,builtin" /f >/dev/null
    wineserver -k >/dev/null 2>&1 || true
    wineserver -w >/dev/null 2>&1 || true
'

write_status "${STATUS_FILE}" "installed-persistent" \
    "native=${NATIVE_RICHEDIT_DLL_HOST},prefix=${WINEPREFIX_HOST}"
printf '%s native RichEdit installed in writable prefix=%s\n' \
    "$(date --iso-8601=seconds)" "${WINEPREFIX_HOST}"
exec "${SCRIPT_DIR}/run-wecom.sh"
