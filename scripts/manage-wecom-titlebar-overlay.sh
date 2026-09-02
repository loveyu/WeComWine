#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C

readonly ACTIVE_WINDOW_PROPERTY="_NET_ACTIVE_WINDOW"
readonly CLIENT_LIST_PROPERTY="_NET_CLIENT_LIST_STACKING"
event_pid=''
cleanup_started=0
declare -A hidden_windows=()

log() {
    printf '%s titlebar-overlay-manager: %s\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S.%3N%:z')" "$*"
}

window_properties() {
    local window_id="$1"

    xprop -id "${window_id}" \
        WM_CLASS \
        _NET_WM_NAME \
        WM_HINTS \
        _NET_WM_WINDOW_TYPE \
        _NET_WM_STATE \
        WM_TRANSIENT_FOR 2>/dev/null
}

window_details() {
    local window_id="$1"

    xwininfo -id "${window_id}" 2>/dev/null | awk '
        /Absolute upper-left X:/ { x = $4 }
        /Absolute upper-left Y:/ { y = $4 }
        /^  Width:/ { width = $2 }
        /^  Height:/ { height = $2 }
        /^  Depth:/ { depth = $2 }
        /Map State:/ { map_state = $3 }
        /Override Redirect State:/ { override_redirect = $4 }
        END {
            if (x != "" && y != "" && width != "" && height != "" &&
                depth != "" && map_state != "" && override_redirect != "") {
                print x, y, width, height, depth, map_state, override_redirect
            } else {
                exit 1
            }
        }
    '
}

absolute_value() {
    local value="$1"

    if (( value < 0 )); then
        printf '%d\n' "$(( -value ))"
    else
        printf '%d\n' "${value}"
    fi
}

titlebar_owner() {
    local window_id="$1"
    local properties=''
    local owner_id=''
    local owner_properties=''
    local overlay_x overlay_y overlay_width overlay_height overlay_depth
    local overlay_map_state overlay_override_redirect
    local owner_x owner_y owner_width owner_height owner_depth
    local owner_map_state owner_override_redirect

    properties="$(window_properties "${window_id}")" || return 1
    grep -Eqi '^WM_CLASS\(STRING\) = "wxwork\.exe", "wxwork\.exe"$' \
        <<< "${properties}" || return 1
    grep -Eq '^_NET_WM_NAME\([^)]*\) = *$' \
        <<< "${properties}" || return 1
    grep -Eq '^_NET_WM_WINDOW_TYPE.*_NET_WM_WINDOW_TYPE_DIALOG' \
        <<< "${properties}" || return 1
    grep -Fq 'Client accepts input or input focus: False' \
        <<< "${properties}" || return 1

    owner_id="$(awk '/^WM_TRANSIENT_FOR/ { print $NF; exit }' \
        <<< "${properties}")"
    [[ "${owner_id}" =~ ^0x[0-9a-fA-F]+$ ]] || return 1

    owner_properties="$(window_properties "${owner_id}")" || return 1
    grep -Eqi '^WM_CLASS\(STRING\) = "wxwork\.exe", "wxwork\.exe"$' \
        <<< "${owner_properties}" || return 1
    grep -Eq '^_NET_WM_WINDOW_TYPE.*_NET_WM_WINDOW_TYPE_NORMAL' \
        <<< "${owner_properties}" || return 1
    grep -Eq '^_NET_WM_STATE.*_NET_WM_STATE_MAXIMIZED_VERT' \
        <<< "${owner_properties}" || return 1
    grep -Eq '^_NET_WM_STATE.*_NET_WM_STATE_MAXIMIZED_HORZ' \
        <<< "${owner_properties}" || return 1

    read -r overlay_x overlay_y overlay_width overlay_height overlay_depth \
        overlay_map_state overlay_override_redirect \
        < <(window_details "${window_id}") || return 1
    read -r owner_x owner_y owner_width owner_height owner_depth \
        owner_map_state owner_override_redirect \
        < <(window_details "${owner_id}") || return 1

    [[ "${overlay_override_redirect}" == "yes" ]] || return 1
    [[ "${owner_override_redirect}" == "no" ]] || return 1
    (( overlay_depth == 32 && owner_depth == 24 )) || return 1
    (( overlay_height >= 24 && overlay_height <= 96 )) || return 1
    (( owner_height >= overlay_height * 4 )) || return 1
    (( $(absolute_value "$(( overlay_x - owner_x ))") <= 8 )) || return 1
    (( $(absolute_value "$(( overlay_y - owner_y ))") <= 8 )) || return 1
    (( $(absolute_value "$(( overlay_width - owner_width ))") <= 8 )) || return 1

    printf '%s\n' "${owner_id}"
}

active_window() {
    xprop -root "${ACTIVE_WINDOW_PROPERTY}" 2>/dev/null | awk '
        match($0, /0x[0-9a-fA-F]+/) { print substr($0, RSTART, RLENGTH); exit }
    '
}

sync_window() {
    local window_id="$1"
    local current_active_window="$2"
    local owner_id=''
    local details=''
    local map_state=''

    owner_id="$(titlebar_owner "${window_id}")" || {
        unset 'hidden_windows['"${window_id}"']'
        return 0
    }
    details="$(window_details "${window_id}")" || return 0
    map_state="$(awk '{ print $6 }' <<< "${details}")"

    if [[ "${current_active_window,,}" == "${owner_id,,}" ]]; then
        if [[ -n "${hidden_windows[${window_id}]:-}" && \
              "${map_state}" != "IsViewable" ]]; then
            if xdotool windowmap "${window_id}" >/dev/null 2>&1; then
                unset 'hidden_windows['"${window_id}"']'
                log "restored window=${window_id} owner=${owner_id}"
            fi
        fi
    elif [[ "${map_state}" == "IsViewable" ]]; then
        if xdotool windowunmap "${window_id}" >/dev/null 2>&1; then
            hidden_windows["${window_id}"]="${owner_id}"
            log "hidden window=${window_id} inactive-owner=${owner_id}"
        fi
    fi
}

scan_windows() {
    local current_active_window=''
    local window_tree=''
    local window_id=''
    local cached_window_id=''
    local -A active_windows=()

    current_active_window="$(active_window)"
    window_tree="$(xwininfo -root -tree 2>/dev/null || true)"
    while IFS= read -r window_id; do
        [[ -n "${window_id}" ]] || continue
        active_windows["${window_id}"]=1
        sync_window "${window_id}" "${current_active_window}"
    done < <(awk '
        tolower($0) ~ /\(has no name\): \("wxwork\.exe" "wxwork\.exe"\)/ {
            split($7, dimensions, "x")
            if (dimensions[1] + 0 > 400 && dimensions[2] + 0 >= 24 &&
                dimensions[2] + 0 <= 96) print $1
        }
    ' <<< "${window_tree}" | sort -u)

    for cached_window_id in "${!hidden_windows[@]}"; do
        if [[ -z "${active_windows[${cached_window_id}]:-}" ]]; then
            unset 'hidden_windows['"${cached_window_id}"']'
        fi
    done
}

stop_event_reader() {
    if [[ -n "${event_pid}" ]]; then
        kill "${event_pid}" 2>/dev/null || true
        wait "${event_pid}" 2>/dev/null || true
        event_pid=''
    fi
}

restore_hidden_windows() {
    local window_id=''

    for window_id in "${!hidden_windows[@]}"; do
        if titlebar_owner "${window_id}" >/dev/null 2>&1; then
            xdotool windowmap "${window_id}" >/dev/null 2>&1 || true
        fi
    done
    hidden_windows=()
}

cleanup() {
    if (( cleanup_started != 0 )); then
        return
    fi
    cleanup_started=1
    stop_event_reader
    restore_hidden_windows
}

trap 'cleanup; exit 0' TERM INT
trap cleanup EXIT

for command_name in xdotool xprop xwininfo awk grep stdbuf sort; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        log "disabled: missing command=${command_name}"
        exit 69
    fi
done

if [[ -z "${DISPLAY:-}" ]]; then
    log 'disabled: DISPLAY is not set'
    exit 69
fi

scan_windows
if [[ "${1:-}" == "--once" ]]; then
    exit 0
fi

while true; do
    coproc WECOM_XPROP_EVENTS {
        exec stdbuf -oL xprop -spy -root \
            "${ACTIVE_WINDOW_PROPERTY}" "${CLIENT_LIST_PROPERTY}" 2>/dev/null
    }
    event_pid="${WECOM_XPROP_EVENTS_PID}"

    while true; do
        if IFS= read -r -t 2 \
            -u "${WECOM_XPROP_EVENTS[0]}" _event; then
            scan_windows
            # Wine can map the unmanaged titlebar shortly after KWin has
            # published the managed owner in the client list.
            sleep 0.1
            scan_windows
            sleep 0.4
            scan_windows
        elif kill -0 "${event_pid}" 2>/dev/null; then
            # Catch delayed window creation and application-driven remaps.
            scan_windows
        else
            break
        fi
    done

    wait "${event_pid}" 2>/dev/null || true
    event_pid=''
    sleep 1
done
