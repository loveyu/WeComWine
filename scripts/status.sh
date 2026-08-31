#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

printf '== systemd ==\n'
systemctl --user --no-pager --full status \
    wecom-flatpak-poc-bootstrap.service \
    wecom-flatpak-poc-app.service \
    wecom-flatpak-poc-build.service \
    wecom-flatpak-poc-switch.service \
    wecom-flatpak-poc-portal-test.service || true

printf '\n== runner ==\n'
printf 'active_app=%s\n' "${ACTIVE_FLATPAK_APP}"
printf 'active_branch=%s\n' "${ACTIVE_FLATPAK_BRANCH}"
printf 'wineprefix_host=%s\n' "${WINEPREFIX_HOST}"
printf 'wineprefix_sandbox=%s\n' "${WINEPREFIX_SANDBOX}"

printf '\n== state ==\n'
for status_file in "${STATE_DIR}"/*.status; do
    [[ -e "${status_file}" ]] || continue
    printf -- '--- %s ---\n' "${status_file}"
    sed -n '1,40p' "${status_file}"
done

printf '\n== processes ==\n'
ps -eo pid,ppid,lstart,cmd | \
    grep -E 'WXWork|wineserver|org.winehq.Wine|io.github.huzhiyu.WeComWine|build-portal-wine' | \
    grep -v grep || true

printf '\n== bootstrap log ==\n'
tail -n 80 "${LOG_DIR}/bootstrap.log" 2>/dev/null || true

printf '\n== app log ==\n'
tail -n 120 "${LOG_DIR}/app.log" 2>/dev/null || true

printf '\n== portal build log ==\n'
tail -n 80 "${LOG_DIR}/portal-build.log" 2>/dev/null || true

printf '\n== portal switch log ==\n'
tail -n 80 "${LOG_DIR}/portal-switch.log" 2>/dev/null || true

printf '\n== portal test log ==\n'
tail -n 120 "${LOG_DIR}/portal-test.log" 2>/dev/null || true
