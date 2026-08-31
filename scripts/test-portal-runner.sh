#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/portal-test.status"
LOCK_FILE="${STATE_DIR}/portal-test.lock"
LOG_FILE="${LOG_DIR}/portal-test.log"
DBUS_LOG="${LOG_DIR}/portal-dbus.log"
TEST_EXE='Z:\app\share\wecom-portal-tests\portal-smoke.exe'
monitor_pid=''
baseline_instances=''

rotate_log "${LOG_FILE}"
exec >> "${LOG_FILE}" 2>&1
exec 9> "${LOCK_FILE}"

if ! flock -n 9; then
    printf '%s portal tests already running\n' "$(date --iso-8601=seconds)"
    exit 0
fi

cleanup() {
    if [[ -n "${monitor_pid}" ]]; then
        kill "${monitor_pid}" 2>/dev/null || true
        wait "${monitor_pid}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if [[ "${ACTIVE_FLATPAK_APP}" != "${PORTAL_FLATPAK_APP}" ]]; then
    write_status "${STATUS_FILE}" "failed" "active-runner=${ACTIVE_FLATPAK_APP}"
    exit 30
fi

# Portal API verification must not share a wineserver or registry with the
# continuously running WeCom process.
WINEPREFIX_HOST="${PORTAL_TEST_WINEPREFIX_HOST}"
WINEPREFIX_SANDBOX="${PORTAL_TEST_WINEPREFIX_HOST}"
mkdir -p "${PORTAL_TEST_WINEPREFIX_HOST}"

write_status "${STATUS_FILE}" "initialize-prefix" "${PORTAL_TEST_WINEPREFIX_HOST}"
flatpak_wine wineboot --update
flatpak_wine wineserver --wait

write_status "${STATUS_FILE}" "running" "legacy+IFileDialog+folder"
: > "${DBUS_LOG}"
baseline_instances="$(flatpak ps --columns=instance,application 2>/dev/null | \
    awk -v app="${PORTAL_FLATPAK_APP}" '$2 == app { print $1 }')"
dbus-monitor --session \
    "type='method_call',interface='org.freedesktop.portal.FileChooser'" \
    >> "${DBUS_LOG}" 2>&1 &
monitor_pid="$!"
sleep 1

WINEDEBUG_VALUE='-all,+commdlg,+shell'
export PORTAL_SMOKE_TIMEOUT_MS=3000
for mode in open opena save savea folder ifileopen ifilesave hook; do
    printf '%s test mode=%s\n' "$(date --iso-8601=seconds)" "${mode}"
    set +e
    flatpak_wine wine "${TEST_EXE}" "${mode}"
    test_exit="$?"
    set -e
    printf '%s test mode=%s exit=%s\n' \
        "$(date --iso-8601=seconds)" "${mode}" "${test_exit}"
    while read -r instance_id; do
        [[ -n "${instance_id}" ]] || continue
        if ! grep -Fxq "${instance_id}" <<< "${baseline_instances}"; then
            flatpak kill "${instance_id}" 2>/dev/null || true
        fi
    done < <(flatpak ps --columns=instance,application 2>/dev/null | \
        awk -v app="${PORTAL_FLATPAK_APP}" '$2 == app { print $1 }')
    sleep 1
done

cleanup
monitor_pid=''

open_calls="$(grep -c 'member=OpenFile' "${DBUS_LOG}" || true)"
save_calls="$(grep -c 'member=SaveFile' "${DBUS_LOG}" || true)"
if (( open_calls != 4 || save_calls != 3 )); then
    write_status "${STATUS_FILE}" "failed" "open=${open_calls},save=${save_calls}"
    exit 31
fi

write_status "${STATUS_FILE}" "complete" "open=${open_calls},save=${save_calls}"
printf '%s portal smoke tests complete: open=%s save=%s\n' \
    "$(date --iso-8601=seconds)" "${open_calls}" "${save_calls}"
