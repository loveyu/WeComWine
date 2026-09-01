#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C

readonly CLIENT_LIST_PROPERTY="_NET_CLIENT_LIST_STACKING"
event_pid=''

log() {
    printf '%s shadow-suppressor: %s\n' "$(date --iso-8601=seconds)" "$*"
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

window_geometry() {
    local window_id="$1"

    xwininfo -id "${window_id}" 2>/dev/null | awk '
        /Absolute upper-left X:/ { x = $4 }
        /Absolute upper-left Y:/ { y = $4 }
        /^  Width:/ { width = $2 }
        /^  Height:/ { height = $2 }
        END {
            if (x != "" && y != "" && width != "" && height != "") {
                print x, y, width, height
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

is_wecom_shadow() {
    local window_id="$1"
    local properties=''
    local transient_id=''
    local outer_x outer_y outer_width outer_height
    local inner_x inner_y inner_width inner_height
    local margin_x margin_y width_delta height_delta

    properties="$(window_properties "${window_id}")" || return 1

    grep -Eqi '^WM_CLASS\(STRING\) = "wxwork\.exe", "wxwork\.exe"$' \
        <<< "${properties}" || return 1
    grep -Eq '^_NET_WM_NAME\([^)]*\) = *$' \
        <<< "${properties}" || return 1
    grep -Eq '^_NET_WM_WINDOW_TYPE.*_NET_WM_WINDOW_TYPE_DIALOG' \
        <<< "${properties}" || return 1
    grep -Eq '^_NET_WM_STATE.*_NET_WM_STATE_SKIP_TASKBAR' \
        <<< "${properties}" || return 1
    grep -Eq '^_NET_WM_STATE.*_NET_WM_STATE_SKIP_PAGER' \
        <<< "${properties}" || return 1
    grep -Fq 'Client accepts input or input focus: False' \
        <<< "${properties}" || return 1

    transient_id="$(awk '/^WM_TRANSIENT_FOR/ { print $NF; exit }' \
        <<< "${properties}")"
    [[ "${transient_id}" =~ ^0x[0-9a-fA-F]+$ ]] || return 1

    window_properties "${transient_id}" | \
        grep -Eqi '^WM_CLASS\(STRING\) = "wxwork\.exe", "wxwork\.exe"$' || \
        return 1

    read -r outer_x outer_y outer_width outer_height \
        < <(window_geometry "${window_id}") || return 1
    read -r inner_x inner_y inner_width inner_height \
        < <(window_geometry "${transient_id}") || return 1

    margin_x=$(( inner_x - outer_x ))
    margin_y=$(( inner_y - outer_y ))
    width_delta=$(( outer_width - inner_width - (2 * margin_x) ))
    height_delta=$(( outer_height - inner_height - (2 * margin_y) ))

    # WeCom renders its shadow as an unfocusable, centered ARGB dialog around
    # the real window. Allow a small rounding tolerance for fractional scaling.
    (( margin_x >= 4 && margin_x <= 128 )) || return 1
    (( margin_y >= 4 && margin_y <= 128 )) || return 1
    (( $(absolute_value "$(( margin_x - margin_y ))") <= 4 )) || return 1
    (( $(absolute_value "${width_delta}") <= 2 )) || return 1
    (( $(absolute_value "${height_delta}") <= 2 )) || return 1
}

suppress_window() {
    local window_id="$1"
    local opacity=''

    is_wecom_shadow "${window_id}" || return 0

    opacity="$(xprop -id "${window_id}" _NET_WM_WINDOW_OPACITY 2>/dev/null || true)"
    if [[ "${opacity}" == *'= 0' ]]; then
        return 0
    fi

    if xprop -id "${window_id}" \
        -f _NET_WM_WINDOW_OPACITY 32c \
        -set _NET_WM_WINDOW_OPACITY 0 >/dev/null 2>&1; then
        log "suppressed window=${window_id}"
    fi
}

scan_windows() {
    local clients=''
    local window_id=''

    clients="$(xprop -root "${CLIENT_LIST_PROPERTY}" 2>/dev/null || true)"
    while IFS= read -r window_id; do
        [[ -n "${window_id}" ]] || continue
        suppress_window "${window_id}"
    done < <(grep -Eo '0x[0-9a-fA-F]+' <<< "${clients}" || true)
}

stop_event_reader() {
    if [[ -n "${event_pid}" ]]; then
        kill "${event_pid}" 2>/dev/null || true
        wait "${event_pid}" 2>/dev/null || true
    fi
}

trap 'stop_event_reader; exit 0' TERM INT
trap stop_event_reader EXIT

for command_name in xprop xwininfo awk grep; do
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
        exec xprop -spy -root "${CLIENT_LIST_PROPERTY}" 2>/dev/null
    }
    event_pid="${WECOM_XPROP_EVENTS_PID}"

    while IFS= read -r -u "${WECOM_XPROP_EVENTS[0]}" _event; do
        scan_windows
    done

    wait "${event_pid}" 2>/dev/null || true
    event_pid=''
    sleep 1
done
