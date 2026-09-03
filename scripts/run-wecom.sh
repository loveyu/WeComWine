#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/app.status"
LOCK_FILE="${STATE_DIR}/app.lock"
INSTANCE_FILE="${STATE_DIR}/app.instance"
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

# A direct launch from the Flatpak-exported desktop file does not own this
# service's host lock.  Avoid starting another client against the same prefix.
if flatpak ps --columns=application 2>/dev/null | \
   grep -Fxq "${ACTIVE_FLATPAK_APP}"; then
    write_status "${STATUS_FILE}" "already-running" \
        "flatpak=${ACTIVE_FLATPAK_APP}"
    exit 0
fi

program_windows="$(<"${PROGRAM_FILE}")"
scale_factor="$(detect_system_scale_factor)"
wine_dpi="$(scale_factor_to_wine_dpi "${scale_factor}")"
deepin_official_baseline=0
if [[ "${ACTIVE_FLATPAK_APP}" == "${DEEPIN_FLATPAK_APP}" ]]; then
    deepin_official_baseline=1
fi
force_portal_default=1
if (( deepin_official_baseline == 1 )); then
    force_portal_default=0
fi
force_portal="${WECOM_FORCE_PORTAL:-${force_portal_default}}"
if [[ "${force_portal}" != "0" && "${force_portal}" != "1" ]]; then
    write_status "${STATUS_FILE}" "failed" \
        "invalid-WECOM_FORCE_PORTAL=${force_portal}"
    printf 'WECOM_FORCE_PORTAL 只允许 0 或 1，当前值：%s\n' \
        "${force_portal}" >&2
    exit 64
fi
if [[ "${force_portal}" == "1" ]]; then
    export WINE_FORCE_PORTAL=1
else
    unset WINE_FORCE_PORTAL
fi
write_status "${STATUS_FILE}" "starting" \
    "${program_windows},scale=${scale_factor},dpi=${wine_dpi},force-portal=${force_portal}"
printf '%s starting %s scale=%s dpi=%s force-portal=%s\n' \
    "$(date --iso-8601=seconds)" "${program_windows}" \
    "${scale_factor}" "${wine_dpi}" "${force_portal}"

runner_pid=''
shadow_suppressor_pid=''
window_icon_manager_pid=''
image_clipboard_bridge_pid=''
stop_requested=0
wecom_runtime_args=()

# The Deepin application payload now uses the same Wine 11 software-rendering
# path as the historically validated runner. URI handoff then reaches
# winebrowser and the Flatpak OpenURI portal.
if (( deepin_official_baseline == 1 )); then
    wecom_runtime_args+=(--disable-gpu)
fi

# WeCom's bundled Chromium repeatedly respawns its GPU process when ANGLE
# cannot create a D3D11 or D3D9 device under Wine.  Besides wasting CPU, the
# restart storm has preceded reproducible stack-overflow crashes in the main
# client.  Keep Chromium on its software compositing path by default; this can
# be disabled temporarily when testing a newer Wine graphics stack.
if (( deepin_official_baseline == 0 )) && \
   [[ "${WECOM_DISABLE_GPU:-1}" != "0" ]]; then
    wecom_runtime_args+=(--disable-gpu)
fi

stop_shadow_suppressor() {
    if [[ -n "${shadow_suppressor_pid}" ]]; then
        kill "${shadow_suppressor_pid}" 2>/dev/null || true
        wait "${shadow_suppressor_pid}" 2>/dev/null || true
        shadow_suppressor_pid=''
    fi
}

stop_window_icon_manager() {
    if [[ -n "${window_icon_manager_pid}" ]]; then
        kill "${window_icon_manager_pid}" 2>/dev/null || true
        wait "${window_icon_manager_pid}" 2>/dev/null || true
        window_icon_manager_pid=''
    fi
}

stop_image_clipboard_bridge() {
    if [[ -n "${image_clipboard_bridge_pid}" ]]; then
        kill "${image_clipboard_bridge_pid}" 2>/dev/null || true
        wait "${image_clipboard_bridge_pid}" 2>/dev/null || true
        image_clipboard_bridge_pid=''
    fi
}

stop_runtime_helpers() {
    stop_shadow_suppressor
    stop_window_icon_manager
    stop_image_clipboard_bridge
}

stop_flatpak_instance() {
    local instance_id=''

    if [[ -s "${INSTANCE_FILE}" ]]; then
        IFS= read -r instance_id < "${INSTANCE_FILE}" || true
    fi
    if [[ "${instance_id}" =~ ^[0-9]+$ ]]; then
        flatpak kill "${instance_id}" 2>/dev/null || true
    fi
}

stop_runner() {
    stop_requested=1
    stop_flatpak_instance
    if [[ -n "${runner_pid}" ]]; then
        kill "${runner_pid}" 2>/dev/null || true
    fi
}

trap stop_runner TERM INT
trap stop_runtime_helpers EXIT

if (( deepin_official_baseline == 0 )) && \
   [[ "${WECOM_DISABLE_WINDOW_SHADOW:-0}" != "0" ]]; then
    "${SCRIPT_DIR}/suppress-wecom-shadow.sh" 9>&- &
    shadow_suppressor_pid="$!"
fi

if (( deepin_official_baseline == 0 )) && \
   [[ "${WECOM_MANAGE_WINDOW_ICON:-1}" != "0" ]]; then
    "${SCRIPT_DIR}/manage-wecom-window-icon.sh" 9>&- &
    window_icon_manager_pid="$!"
fi

if (( deepin_official_baseline == 0 )) && \
   [[ "${WECOM_IMAGE_CLIPBOARD_BRIDGE:-1}" != "0" ]]; then
    "${SCRIPT_DIR}/bridge-wecom-image-clipboard.sh" 9>&- &
    image_clipboard_bridge_pid="$!"
fi

set +e
printf '%s runtime args:' "$(date --iso-8601=seconds)"
printf ' %q' "${wecom_runtime_args[@]}"
printf '\n'
: > "${INSTANCE_FILE}"
exec 8> "${INSTANCE_FILE}"
FLATPAK_INSTANCE_ID_FD=8 \
    flatpak_wine_scaled "${wine_dpi}" sh -c '
        has_update_package() {
            find "${WINEPREFIX}/drive_c/users" -type f \
                -path "*/AppData/Roaming/Tencent/WXWork/Update/Update.exe" \
                -print -quit | grep -q .
        }

        update_pending=0
        if has_update_package; then
            update_pending=1
        fi
        wine "$@"
        wine_status="$?"

        # WeCom exits its main process before the in-prefix updater has
        # finished.  Keep this Flatpak instance and wineserver alive long
        # enough for that child installer to persist the new version.
        if [ "${wine_status}" -eq 0 ] && \
           { [ "${update_pending}" -eq 1 ] || has_update_package; }; then
            printf "%s waiting for WeCom updater to finish\n" \
                "$(date --iso-8601=seconds)"
            timeout --foreground 15m wineserver -w || true
        fi
        exit "${wine_status}"
    ' sh "${program_windows}" "${wecom_runtime_args[@]}" 9>&- &
runner_pid="$!"
exec 8>&-
sleep 2
if kill -0 "${runner_pid}" 2>/dev/null; then
    write_status "${STATUS_FILE}" "running" \
        "${program_windows},scale=${scale_factor},dpi=${wine_dpi},force-portal=${force_portal}"
fi
wait "${runner_pid}"
wine_exit_code="$?"
# Wine helpers such as wineserver and the Bugly crash handler can outlive the
# main executable.  Stop only this launch's Flatpak instance so those helpers
# cannot retain the prefix or lock, while independent builds and smoke tests
# using the same application ID remain untouched.
stop_flatpak_instance
stop_runtime_helpers
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
