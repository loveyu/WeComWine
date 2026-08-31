#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/portal-switch.status"
LOCK_FILE="${STATE_DIR}/portal-switch.lock"
LOG_FILE="${LOG_DIR}/portal-switch.log"
switch_complete=0

rotate_log "${LOG_FILE}"
exec >> "${LOG_FILE}" 2>&1
exec 9> "${LOCK_FILE}"

if ! flock -n 9; then
    printf '%s portal runner switch already running\n' "$(date --iso-8601=seconds)"
    write_status "${STATUS_FILE}" "waiting-lock" "retry-in-60s"
    exit 75
fi

on_error() {
    local exit_code="$?"
    local line_number="${BASH_LINENO[0]:-unknown}"

    write_status "${STATUS_FILE}" "failed" "exit=${exit_code},line=${line_number}"
    printf '%s portal runner switch failed: exit=%s line=%s\n' \
        "$(date --iso-8601=seconds)" "${exit_code}" "${line_number}"
    if (( switch_complete == 0 )); then
        printf '%s\n' "${FLATPAK_APP}" > "${RUNNER_STATE_FILE}"
        systemctl --user start --no-block wecom-flatpak-poc.target || true
    fi
    exit "${exit_code}"
}

trap on_error ERR

write_status "${STATUS_FILE}" "verify-runner" "${PORTAL_FLATPAK_APP}"
flatpak info --user "${PORTAL_FLATPAK_APP}//${PORTAL_FLATPAK_BRANCH}"

write_status "${STATUS_FILE}" "stop-baseline" "wecom-flatpak-poc.target"
systemctl --user stop wecom-flatpak-poc.target
flatpak kill "${FLATPAK_APP}" 2>/dev/null || true
flatpak kill "${PORTAL_FLATPAK_APP}" 2>/dev/null || true

write_status "${STATUS_FILE}" "migrate-prefix" "${SHARED_WINEPREFIX_HOST}"
mkdir -p "$(dirname "${SHARED_WINEPREFIX_HOST}")"
if [[ ! -f "${SHARED_WINEPREFIX_HOST}/system.reg" ]]; then
    if [[ ! -f "${ORIGINAL_WINEPREFIX_HOST}/system.reg" ]]; then
        printf 'neither shared nor original Wine prefix is valid\n'
        exit 20
    fi
    mv "${ORIGINAL_WINEPREFIX_HOST}" "${SHARED_WINEPREFIX_HOST}"
fi

printf '%s\n' "${PORTAL_FLATPAK_APP}" > "${RUNNER_STATE_FILE}"
source "${SCRIPT_DIR}/common.sh"

write_status "${STATUS_FILE}" "configure-portal" "FileDialogPortal=auto"
flatpak_wine sh /app/share/wecom-portal-tests/configure-prefix.sh

write_status "${STATUS_FILE}" "start-wecom" "${PORTAL_FLATPAK_APP}"
flock -u 9
exec 9>&-
systemctl --user start wecom-flatpak-poc.target
switch_complete=1
write_status "${STATUS_FILE}" "complete" "${PORTAL_FLATPAK_APP}"
printf '%s portal runner switch complete\n' "$(date --iso-8601=seconds)"
