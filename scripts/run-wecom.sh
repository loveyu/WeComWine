#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/app.status"
LOCK_FILE="${STATE_DIR}/app.lock"
PROGRAM_FILE="${STATE_DIR}/program.path"
LOG_FILE="${LOG_DIR}/app.log"

rotate_log "${LOG_FILE}"
exec >> "${LOG_FILE}" 2>&1
exec 9> "${LOCK_FILE}"

if ! flock -n 9; then
    write_status "${STATUS_FILE}" "already-running" "lock=${LOCK_FILE}"
    exit 0
fi

if [[ ! -s "${PROGRAM_FILE}" ]]; then
    write_status "${STATUS_FILE}" "failed" "missing=${PROGRAM_FILE}"
    exit 4
fi

program_windows="$(<"${PROGRAM_FILE}")"
scale_factor="$(detect_system_scale_factor)"
wine_dpi="$(scale_factor_to_wine_dpi "${scale_factor}")"
write_status "${STATUS_FILE}" "starting" \
    "${program_windows},scale=${scale_factor},dpi=${wine_dpi}"
printf '%s starting %s scale=%s dpi=%s\n' \
    "$(date --iso-8601=seconds)" "${program_windows}" \
    "${scale_factor}" "${wine_dpi}"

runner_pid=''
shadow_suppressor_pid=''
stop_requested=0

stop_shadow_suppressor() {
    if [[ -n "${shadow_suppressor_pid}" ]]; then
        kill "${shadow_suppressor_pid}" 2>/dev/null || true
        wait "${shadow_suppressor_pid}" 2>/dev/null || true
        shadow_suppressor_pid=''
    fi
}

stop_runner() {
    stop_requested=1
    flatpak kill "${ACTIVE_FLATPAK_APP}" 2>/dev/null || true
    if [[ -n "${runner_pid}" ]]; then
        kill "${runner_pid}" 2>/dev/null || true
    fi
}

trap stop_runner TERM INT
trap stop_shadow_suppressor EXIT

if [[ "${WECOM_DISABLE_WINDOW_SHADOW:-1}" != "0" ]]; then
    "${SCRIPT_DIR}/suppress-wecom-shadow.sh" &
    shadow_suppressor_pid="$!"
fi

set +e
flatpak_wine_scaled "${wine_dpi}" wine "${program_windows}" &
runner_pid="$!"
sleep 2
if kill -0 "${runner_pid}" 2>/dev/null; then
    write_status "${STATUS_FILE}" "running" \
        "${program_windows},scale=${scale_factor},dpi=${wine_dpi}"
fi
wait "${runner_pid}"
wine_exit_code="$?"
flatpak kill "${ACTIVE_FLATPAK_APP}" 2>/dev/null || true
stop_shadow_suppressor
set -e

write_status "${STATUS_FILE}" "exited" \
    "wine=${wine_exit_code},stop-requested=${stop_requested}"
printf '%s exited: wine=%s stop-requested=%s\n' \
    "$(date --iso-8601=seconds)" "${wine_exit_code}" "${stop_requested}"

if (( stop_requested != 0 )); then
    exit 0
fi

if (( wine_exit_code != 0 )); then
    exit "${wine_exit_code}"
fi

exit 0
