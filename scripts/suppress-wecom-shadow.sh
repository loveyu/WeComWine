#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C

readonly CLIENT_LIST_PROPERTY="_NET_CLIENT_LIST_STACKING"
event_pid=''
declare -A suppressed_windows=()

log() {
    printf '%s shadow-suppressor: %s\n' \
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

window_geometry() {
    local window_id="$1"

    xwininfo -id "${window_id}" 2>/dev/null | awk '
        /Absolute upper-left X:/ { x = $4 }
        /Absolute upper-left Y:/ { y = $4 }
        /^  Width:/ { width = $2 }
        /^  Height:/ { height = $2 }
        /^  Depth:/ { depth = $2 }
        END {
            if (x != "" && y != "" && width != "" && height != "" &&
                depth != "") {
                print x, y, width, height, depth
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
    local outer_x outer_y outer_width outer_height outer_depth
    local inner_x inner_y inner_width inner_height inner_depth
    local margin_left margin_right margin_top margin_bottom
    local margin

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
    grep -Eq '^_NET_WM_STATE.*_KDE_NET_WM_STATE_SKIP_SWITCHER' \
        <<< "${properties}" || return 1
    grep -Fq 'Client accepts input or input focus: False' \
        <<< "${properties}" || return 1

    transient_id="$(awk '/^WM_TRANSIENT_FOR/ { print $NF; exit }' \
        <<< "${properties}")"
    [[ "${transient_id}" =~ ^0x[0-9a-fA-F]+$ ]] || return 1

    window_properties "${transient_id}" | \
        grep -Eqi '^WM_CLASS\(STRING\) = "wxwork\.exe", "wxwork\.exe"$' || \
        return 1

    read -r outer_x outer_y outer_width outer_height outer_depth \
        < <(window_geometry "${window_id}") || return 1
    read -r inner_x inner_y inner_width inner_height inner_depth \
        < <(window_geometry "${transient_id}") || return 1

    (( outer_depth == 32 && inner_depth == 24 )) || return 1

    margin_left=$(( inner_x - outer_x ))
    margin_right=$(( outer_x + outer_width - inner_x - inner_width ))
    margin_top=$(( inner_y - outer_y ))
    margin_bottom=$(( outer_y + outer_height - inner_y - inner_height ))

    # WeCom renders its shadow as an unfocusable ARGB dialog around the real
    # window. Forced system borders can shift the real window within that
    # dialog, so allow asymmetric (and even zero-width) edges while still
    # requiring a material margin in both dimensions.
    for margin in \
        "${margin_left}" "${margin_right}" "${margin_top}" "${margin_bottom}"; do
        (( margin >= 0 && margin <= 128 )) || return 1
    done
    (( margin_left + margin_right >= 8 )) || return 1
    (( margin_top + margin_bottom >= 8 )) || return 1
    (( $(absolute_value "$(( margin_left - margin_right ))") <= 64 )) || return 1
    (( $(absolute_value "$(( margin_top - margin_bottom ))") <= 64 )) || return 1
}

suppress_window() {
    local window_id="$1"
    local opacity=''

    is_wecom_shadow "${window_id}" || return 0

    # WeCom periodically removes the opacity property from a live shadow
    # window. Re-applying it produces a PropertyNotify tug-of-war and was the
    # only controllable external action observed at the timestamp of two
    # stack-overflow dumps. Suppress each XID once per window lifetime; a
    # later scan drops the cache entry after the XID leaves the window tree.
    if [[ -n "${suppressed_windows[${window_id}]:-}" ]]; then
        return 0
    fi

    opacity="$(xprop -id "${window_id}" _NET_WM_WINDOW_OPACITY 2>/dev/null || true)"
    if [[ "${opacity}" == *'= 0' ]]; then
        suppressed_windows["${window_id}"]=1
        return 0
    fi

    if xprop -id "${window_id}" \
        -f _NET_WM_WINDOW_OPACITY 32c \
        -set _NET_WM_WINDOW_OPACITY 0 >/dev/null 2>&1; then
        suppressed_windows["${window_id}"]=1
        log "suppressed window=${window_id}"
    fi
}

scan_windows() {
    local candidates=''
    local cached_window_id=''
    local window_tree=''
    local window_id=''
    local -A active_windows=()

    # The full tree includes managed, reparented and override-redirect Wine
    # windows. Pre-filter it before launching xprop so a fallback scan only
    # inspects sizeable, untitled WeCom candidates rather than every desktop
    # and helper window.
    window_tree="$(xwininfo -root -tree 2>/dev/null || true)"
    while IFS= read -r window_id; do
        [[ -n "${window_id}" ]] || continue
        active_windows["${window_id}"]=1
    done < <(awk '
        tolower($0) ~ /\("wxwork\.exe" "wxwork\.exe"\)/ { print $1 }
    ' <<< "${window_tree}")

    candidates="$(awk '
        tolower($0) ~ /\(has no name\): \("wxwork\.exe" "wxwork\.exe"\)/ {
            split($7, dimensions, "x")
            if (dimensions[1] + 0 > 8 && dimensions[2] + 0 > 8) print $1
        }
    ' <<< "${window_tree}")"
    while IFS= read -r window_id; do
        [[ -n "${window_id}" ]] || continue
        suppress_window "${window_id}"
    done <<< "${candidates}"

    for cached_window_id in "${!suppressed_windows[@]}"; do
        if [[ -z "${active_windows[${cached_window_id}]:-}" ]]; then
            unset 'suppressed_windows['"${cached_window_id}"']'
        fi
    done
}

stop_event_reader() {
    if [[ -n "${event_pid}" ]]; then
        kill "${event_pid}" 2>/dev/null || true
        wait "${event_pid}" 2>/dev/null || true
    fi
}

trap 'stop_event_reader; exit 0' TERM INT
trap stop_event_reader EXIT

for command_name in xprop xwininfo awk grep stdbuf; do
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
            "${CLIENT_LIST_PROPERTY}" 2>/dev/null
    }
    event_pid="${WECOM_XPROP_EVENTS_PID}"

    while true; do
        if IFS= read -r -t 5 \
            -u "${WECOM_XPROP_EVENTS[0]}" _event; then
            scan_windows
            # Wine can publish the window list before its WM_CLASS, transient
            # relationship and state hints are all visible.
            sleep 0.1
            scan_windows
            sleep 0.4
            scan_windows
        elif kill -0 "${event_pid}" 2>/dev/null; then
            # Wine does not expose a single event that means "all window hints
            # are complete". This low-frequency fallback is required for the
            # delayed updates observed during startup and popup creation. A
            # five-second interval keeps the steady-state overhead negligible.
            scan_windows
        else
            break
        fi
    done

    wait "${event_pid}" 2>/dev/null || true
    event_pid=''
    sleep 1
done
