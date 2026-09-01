#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/native-richedit.status"

if [[ "${WECOM_NATIVE_RICHEDIT_STAGE:-}" == "inner" ]]; then
    install -m 0644 "${NATIVE_RICHEDIT_DLL_HOST}" \
        "${WINEPREFIX_HOST}/drive_c/windows/syswow64/riched20.dll"

    WINEDEBUG_VALUE=-all flatpak_wine sh -c '
        wine reg.exe add "HKCU\Software\Wine\DllOverrides" \
            /v riched20 /d "native,builtin" /f >/dev/null
        wineserver -k >/dev/null 2>&1 || true
        wineserver -w >/dev/null 2>&1 || true
    '

    write_status "${STATUS_FILE}" "running" \
        "native=${NATIVE_RICHEDIT_DLL_HOST},live-users=${WINEPREFIX_HOST}/drive_c/users"
    exec "${SCRIPT_DIR}/run-wecom.sh"
fi

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

# DLL and registry writes stay in the disposable overlay.  User files remain
# live so WeCom login-token rotations survive process and machine restarts.
cleanup_overlay_dir() {
    local candidate="$1"

    case "${candidate}" in
        "${STATE_DIR}"/native-richedit-runtime.*) ;;
        *)
            printf '拒绝清理非 RichEdit 运行目录：%s\n' "${candidate}" >&2
            return 64
            ;;
    esac

    # OverlayFS leaves its private work/work directory at mode 000.  Restore
    # owner traversal before removal; otherwise every service restart leaks a
    # small runtime directory.
    chmod u+rwx -- "${candidate}/work/work" 2>/dev/null || true
    rm -rf -- "${candidate}" 2>/dev/null || true
}

# Recover from SIGKILL, power loss, or a previous version without complete
# cleanup.  A live owner PID always wins, even if it has been reused.
shopt -s nullglob
for stale_overlay in "${STATE_DIR}"/native-richedit-runtime.*; do
    stale_owner=''
    if [[ -s "${stale_overlay}/owner.pid" ]]; then
        IFS= read -r stale_owner < "${stale_overlay}/owner.pid" || true
    fi
    if [[ "${stale_owner}" =~ ^[0-9]+$ ]] && \
       kill -0 "${stale_owner}" 2>/dev/null; then
        continue
    fi
    cleanup_overlay_dir "${stale_overlay}"
done
shopt -u nullglob

overlay_root="$(mktemp -d "${STATE_DIR}/native-richedit-runtime.XXXXXX")"
mkdir -p "${overlay_root}/upper" "${overlay_root}/work"
printf '%s\n' "$$" > "${overlay_root}/owner.pid"
cleanup_overlay() {
    if [[ "${WECOM_NATIVE_RICHEDIT_KEEP_OVERLAY:-0}" != "1" ]]; then
        cleanup_overlay_dir "${overlay_root}"
    fi
}
trap cleanup_overlay EXIT

write_status "${STATUS_FILE}" "starting" \
    "overlay=${overlay_root},live-users=${WINEPREFIX_HOST}/drive_c/users"
printf '%s native RichEdit runtime overlay=%s\n' \
    "$(date --iso-8601=seconds)" "${overlay_root}"

set +e
bwrap \
    --dev-bind / / \
    --overlay-src "${WINEPREFIX_HOST}" \
    --overlay "${overlay_root}/upper" "${overlay_root}/work" \
        "${WINEPREFIX_HOST}" \
    --bind "${WINEPREFIX_HOST}/drive_c/users" \
        "${WINEPREFIX_HOST}/drive_c/users" \
    env \
        WECOM_NATIVE_RICHEDIT_STAGE=inner \
        "${SCRIPT_DIR}/run-wecom-native-richedit.sh"
exit_code="$?"
set -e

write_status "${STATUS_FILE}" "exited" \
    "code=${exit_code},overlay=${overlay_root}"
exit "${exit_code}"
