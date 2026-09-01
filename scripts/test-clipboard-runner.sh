#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/clipboard-test.status"
LOCK_FILE="${STATE_DIR}/clipboard-test.lock"
LOG_FILE="${LOG_DIR}/clipboard-test.log"
TEST_EXE='Z:\app\share\wecom-portal-tests\clipboard-smoke.exe'
RICHEDIT_TEST_EXE='Z:\app\share\wecom-portal-tests\richedit-image-paste-smoke.exe'

rotate_log "${LOG_FILE}"
exec >> "${LOG_FILE}" 2>&1
exec 9> "${LOCK_FILE}"

if ! flock -n 9; then
    printf '%s clipboard test already running\n' "$(date --iso-8601=seconds)"
    exit 0
fi

if [[ "${ACTIVE_FLATPAK_APP}" != "${PORTAL_FLATPAK_APP}" ]]; then
    write_status "${STATUS_FILE}" "failed" "active-runner=${ACTIVE_FLATPAK_APP}"
    exit 30
fi

# Never share the continuously running WeCom wineserver or prefix. The probe
# only reads the current desktop clipboard and exits without replacing it.
WINEPREFIX_HOST="${PORTAL_TEST_WINEPREFIX_HOST}"
WINEPREFIX_SANDBOX="${PORTAL_TEST_WINEPREFIX_HOST}"
mkdir -p "${PORTAL_TEST_WINEPREFIX_HOST}"

run_with_ephemeral_wineserver() {
    # Keep a shell as the Flatpak init process. A direct `flatpak run wine`
    # can keep waiting after the probe exits because Wine services remain in
    # the PID namespace. Shut down only this isolated prefix before leaving.
    flatpak_wine sh -c '
        command="$1"
        shift
        "$command" "$@"
        rc="$?"
        wineserver -k >/dev/null 2>&1 || true
        wineserver -w >/dev/null 2>&1 || true
        exit "$rc"
    ' sh "$@"
}

write_status "${STATUS_FILE}" "initialize-prefix" "${PORTAL_TEST_WINEPREFIX_HOST}"
run_with_ephemeral_wineserver wineboot --update

write_status "${STATUS_FILE}" "running" "dib+bitmap+enhmetafile+ole+richedit"
set +e
output="$(run_with_ephemeral_wineserver sh -c '
    wine "$1"
    clipboard_exit_code="$?"
    printf "clipboard-smoke-exit=%s\n" "$clipboard_exit_code"

    # Keep the same wineserver alive for both probes.  Once Wine has imported
    # the X11 selection, stopping that wineserver can temporarily leave the
    # desktop clipboard without an owner before the RichEdit probe starts.
    wine "$2"
    richedit_exit_code="$?"
    printf "richedit-smoke-exit=%s\n" "$richedit_exit_code"

    [ "$clipboard_exit_code" -eq 0 ] && [ "$richedit_exit_code" -eq 0 ]
' sh "${TEST_EXE}" "${RICHEDIT_TEST_EXE}")"
test_exit_code="$?"
printf '%s\n' "${output}"
set -e

if (( test_exit_code != 0 )) ||
   ! grep -Eq 'clipboard-smoke-exit=0' <<< "${output}" ||
   ! grep -Eq 'image-availability .*bitmap=1 .*dib=1 .*enhmetafile=1' <<< "${output}" ||
   ! grep -Eq 'enhmetafile bytes=[1-9][0-9]* records=[1-9][0-9]*' <<< "${output}" ||
   ! grep -Eq 'ole-query .*enhmetafile=0x00000000' <<< "${output}"; then
    write_status "${STATUS_FILE}" "failed" "missing-valid-enhmetafile"
    exit 31
fi

if ! grep -Eq 'richedit-smoke-exit=0' <<< "${output}" ||
   ! grep -Eq 'richedit-paste storage-count=[1-9][0-9]* query-count=[2-9][0-9]* standard-rejected=1 accepted-picture=1 accepted-null-storage=1 object-count=[1-9][0-9]* class-ok=1 object-storage-null=1 size=[1-9][0-9]*x[1-9][0-9]*' <<< "${output}"; then
    write_status "${STATUS_FILE}" "failed" \
        "richedit-rejected-enhmetafile,exit=${test_exit_code}"
    exit 32
fi

write_status "${STATUS_FILE}" "complete" "dib+bitmap+enhmetafile+ole+richedit"
printf '%s clipboard smoke test complete\n' "$(date --iso-8601=seconds)"
