#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/native-richedit-ab.status"
NATIVE_RICHEDIT_DLL="${NATIVE_RICHEDIT_DLL:-}"
NATIVE_MSLS31_DLL="${NATIVE_MSLS31_DLL:-}"
NATIVE_USP10_DLL="${NATIVE_USP10_DLL:-}"

validate_native_dll() {
    local path="$1"
    local label="$2"

    if [[ ! -f "${path}" ]]; then
        printf '缺少原生 %s：%s\n' "${label}" "${path}" >&2
        exit 64
    fi
}

if [[ "${NATIVE_RICHEDIT_AB_STAGE:-}" == "inner" ]]; then
    override_names=(riched20)

    install -m 0644 "${NATIVE_RICHEDIT_DLL}" \
        "${SHARED_WINEPREFIX_HOST}/drive_c/windows/syswow64/riched20.dll"
    if [[ -n "${NATIVE_MSLS31_DLL}" ]]; then
        install -m 0644 "${NATIVE_MSLS31_DLL}" \
            "${SHARED_WINEPREFIX_HOST}/drive_c/windows/syswow64/msls31.dll"
        override_names+=(msls31)
    fi
    if [[ -n "${NATIVE_USP10_DLL}" ]]; then
        install -m 0644 "${NATIVE_USP10_DLL}" \
            "${SHARED_WINEPREFIX_HOST}/drive_c/windows/syswow64/usp10.dll"
        override_names+=(usp10)
    fi

    WINEDEBUG_VALUE=-all flatpak_wine sh -c '
        key="HKCU\Software\Wine\DllOverrides"
        for dll in "$@"; do
            wine reg.exe add "$key" /v "$dll" /d "native,builtin" /f \
                >/dev/null || exit $?
        done
        wineserver -k >/dev/null 2>&1 || true
        wineserver -w >/dev/null 2>&1 || true
    ' sh "${override_names[@]}"

    exec "${SCRIPT_DIR}/run-wecom.sh"
fi

validate_native_dll "${NATIVE_RICHEDIT_DLL}" 'riched20.dll'
if [[ -n "${NATIVE_MSLS31_DLL}" ]]; then
    validate_native_dll "${NATIVE_MSLS31_DLL}" 'msls31.dll'
fi
if [[ -n "${NATIVE_USP10_DLL}" ]]; then
    validate_native_dll "${NATIVE_USP10_DLL}" 'usp10.dll'
fi
if [[ ! -f "${SHARED_WINEPREFIX_HOST}/system.reg" ]]; then
    printf '正式 Wine 前缀尚未初始化：%s\n' "${SHARED_WINEPREFIX_HOST}" >&2
    exit 65
fi
if [[ ! -d "${SHARED_WINEPREFIX_HOST}/drive_c/users" ]]; then
    printf '正式 Wine 前缀缺少用户目录：%s\n' \
        "${SHARED_WINEPREFIX_HOST}/drive_c/users" >&2
    exit 65
fi

# OverlayFS keeps DLL and registry changes in a fresh upper directory.  Keep
# drive_c/users bind-mounted from the normal prefix: WeCom rotates login tokens
# while it is running, and hiding those writes in a disposable upper layer
# invalidates the token left in the normal prefix after the A/B process exits.
overlay_root="$(mktemp -d "${STATE_DIR}/native-richedit-overlay.XXXXXX")"
mkdir -p "${overlay_root}/upper" "${overlay_root}/work"
write_status "${STATUS_FILE}" "starting" \
    "overlay=${overlay_root},live-users=${SHARED_WINEPREFIX_HOST}/drive_c/users"
printf '%s native RichEdit A/B overlay=%s\n' \
    "$(date --iso-8601=seconds)" "${overlay_root}"

set +e
bwrap \
    --dev-bind / / \
    --overlay-src "${SHARED_WINEPREFIX_HOST}" \
    --overlay "${overlay_root}/upper" "${overlay_root}/work" \
        "${SHARED_WINEPREFIX_HOST}" \
    --bind "${SHARED_WINEPREFIX_HOST}/drive_c/users" \
        "${SHARED_WINEPREFIX_HOST}/drive_c/users" \
    env \
        NATIVE_RICHEDIT_AB_STAGE=inner \
        NATIVE_RICHEDIT_DLL="${NATIVE_RICHEDIT_DLL}" \
        NATIVE_MSLS31_DLL="${NATIVE_MSLS31_DLL}" \
        NATIVE_USP10_DLL="${NATIVE_USP10_DLL}" \
        "${SCRIPT_DIR}/run-native-richedit-ab.sh"
exit_code="$?"
set -e

write_status "${STATUS_FILE}" "exited" \
    "code=${exit_code},overlay=${overlay_root}"
exit "${exit_code}"
