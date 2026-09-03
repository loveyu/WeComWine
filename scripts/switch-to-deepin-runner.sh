#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/deepin-switch.status"
LOCK_FILE="${STATE_DIR}/deepin-switch.lock"
START_AFTER_SWITCH=0
previous_runner="${PORTAL_FLATPAK_APP}"
switch_complete=0

if [[ -s "${RUNNER_STATE_FILE}" ]]; then
    previous_runner="$(<"${RUNNER_STATE_FILE}")"
fi

on_error() {
    local exit_code="$?"

    if (( switch_complete == 0 )); then
        printf '%s\n' "${previous_runner}" > "${RUNNER_STATE_FILE}"
    fi
    write_status "${STATUS_FILE}" "failed" \
        "exit=${exit_code},restored-runner=${previous_runner}"
    exit "${exit_code}"
}
trap on_error ERR

if [[ "${1:-}" == "--start" ]]; then
    START_AFTER_SWITCH=1
elif [[ -n "${1:-}" ]]; then
    printf '用法：%s [--start]\n' "${0##*/}" >&2
    exit 64
fi

exec 9> "${LOCK_FILE}"
if ! flock -n 9; then
    write_status "${STATUS_FILE}" "waiting-lock" "${LOCK_FILE}"
    exit 75
fi

flatpak info --user "${DEEPIN_FLATPAK_APP}//${DEEPIN_FLATPAK_BRANCH}" >/dev/null
if flatpak run --user --command=sh "${DEEPIN_FLATPAK_APP}" -c '
    test ! -e /app/bin/winedbg &&
    test ! -e /app/bin/winegdb &&
    test ! -e /app/lib/wine/i386-windows/winedbg.exe &&
    test ! -e /app/lib/wine/x86_64-windows/winedbg.exe
'; then
    :
else
    write_status "${STATUS_FILE}" "unsafe-runner" "debugger-entry-present"
    printf 'Deepin Flatpak 中仍存在调试器入口，拒绝切换。\n' >&2
    exit 65
fi

systemctl --user stop wecom-flatpak-poc.target
flatpak kill "${FLATPAK_APP}" 2>/dev/null || true
flatpak kill "${PORTAL_FLATPAK_APP}" 2>/dev/null || true
flatpak kill "${DEEPIN_FLATPAK_APP}" 2>/dev/null || true

printf '%s\n' "${DEEPIN_FLATPAK_APP}" > "${RUNNER_STATE_FILE}"

# Reload common.sh after selecting the new runner.  Initialize exclusively
# from Deepin's complete prefix and adapter, then update the client payload in
# that same prefix with the verified Tencent installer bundled locally.
source "${SCRIPT_DIR}/common.sh"
write_status "${STATUS_FILE}" "initialize-official-prefix" "${DEEPIN_WINEPREFIX_HOST}"
flatpak_wine sh /app/share/wecom-deepin/initialize-prefix.sh
flatpak_wine sh /app/share/wecom-deepin/install-official-wecom.sh
flatpak_wine sh /app/share/wecom-deepin/migrate-prefix-to-wine11.sh

write_status "${STATUS_FILE}" "prepared" \
    "runner=${DEEPIN_FLATPAK_APP},prefix=${DEEPIN_WINEPREFIX_HOST}"
switch_complete=1
if (( START_AFTER_SWITCH == 1 )); then
    systemctl --user start --no-block wecom-flatpak-poc.target
    write_status "${STATUS_FILE}" "started" "${DEEPIN_FLATPAK_APP}"
else
    printf 'Deepin runner 已准备完成，但未启动企业微信。\n'
fi
trap - ERR
