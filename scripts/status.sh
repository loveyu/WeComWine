#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"
load_desktop_environment

printf '== systemd ==\n'
systemctl --user --no-pager --full status \
    wecom-flatpak-poc-bootstrap.service \
    wecom-flatpak-poc-app.service \
    wecom-flatpak-poc-window-integration.service \
    wecom-flatpak-poc-build.service \
    wecom-flatpak-poc-switch.service \
    wecom-flatpak-poc-portal-test.service || true

printf '\n== runner ==\n'
printf 'active_app=%s\n' "${ACTIVE_FLATPAK_APP}"
printf 'active_branch=%s\n' "${ACTIVE_FLATPAK_BRANCH}"
printf 'wineprefix_host=%s\n' "${WINEPREFIX_HOST}"
printf 'wineprefix_sandbox=%s\n' "${WINEPREFIX_SANDBOX}"

if [[ "${ACTIVE_FLATPAK_APP}" == "${DEEPIN_FLATPAK_APP}" ]]; then
    deepin_expected_package="${WECOM_VERSION}deepin11"
    deepin_expected_engine='deepin-wine-10.14'
    deepin_expected_exe_sha256='67419f5b75e4e9e4731061cf9e04fdeaca0e24f080abd8090aa90ee1824049c9'
    deepin_expected_emoji_sha256='de6c18832938afc99caf132b39d6a30a19bac7f2e812e28db2535b4608d27551'
    deepin_program="${WINEPREFIX_HOST}/drive_c/Program Files (x86)/WXWork/WXWork.exe"
    deepin_emoji_font="${WINEPREFIX_HOST}/drive_c/windows/Fonts/NotoEmoji-wght.ttf"
    deepin_package_marker="${WINEPREFIX_HOST}/.deepin-wecom-package"
    deepin_engine_marker="${WINEPREFIX_HOST}/.wine-engine"
    deepin_kernel32="${WINEPREFIX_HOST}/drive_c/windows/system32/kernel32.dll"
    deepin_verified=yes

    printf '\n== Deepin stable baseline ==\n'
    LC_ALL=C flatpak info --user "${DEEPIN_FLATPAK_APP}" 2>/dev/null | \
        sed -n -e '/^[[:space:]]*Version:/p' -e '/^[[:space:]]*Commit:/p' || true
    printf 'package=%s\n' "$(cat "${deepin_package_marker}" 2>/dev/null || printf missing)"
    printf 'engine=%s\n' "$(cat "${deepin_engine_marker}" 2>/dev/null || printf missing)"
    if [[ -f "${deepin_program}" ]]; then
        deepin_exe_sha256="$(sha256sum "${deepin_program}" | awk '{print $1}')"
    else
        deepin_exe_sha256=missing
    fi
    printf 'wxwork_sha256=%s\n' "${deepin_exe_sha256}"
    if [[ -f "${deepin_emoji_font}" ]]; then
        deepin_emoji_sha256="$(sha256sum "${deepin_emoji_font}" | awk '{print $1}')"
    else
        deepin_emoji_sha256=missing
    fi
    printf 'emoji_font_sha256=%s\n' "${deepin_emoji_sha256}"
    printf 'kernel32=%s\n' "$(readlink "${deepin_kernel32}" 2>/dev/null || printf missing)"

    [[ -f "${deepin_package_marker}" ]] && \
        [[ "$(<"${deepin_package_marker}")" == "${deepin_expected_package}" ]] || \
        deepin_verified=no
    [[ -f "${deepin_engine_marker}" ]] && \
        [[ "$(<"${deepin_engine_marker}")" == "${deepin_expected_engine}" ]] || \
        deepin_verified=no
    [[ "${deepin_exe_sha256}" == "${deepin_expected_exe_sha256}" ]] || \
        deepin_verified=no
    [[ "${deepin_emoji_sha256}" == "${deepin_expected_emoji_sha256}" ]] || \
        deepin_verified=no
    [[ -L "${deepin_kernel32}" ]] && \
        [[ "$(readlink "${deepin_kernel32}")" == /app/deepin-wine10-stable/* ]] || \
        deepin_verified=no
    printf 'verified=%s\n' "${deepin_verified}"
fi

printf '\n== native RichEdit ==\n'
printf 'path=%s\n' "${NATIVE_RICHEDIT_DLL_HOST}"
if [[ -f "${NATIVE_RICHEDIT_DLL_HOST}" ]]; then
    native_richedit_sha256="$(sha256sum "${NATIVE_RICHEDIT_DLL_HOST}" | awk '{print $1}')"
    printf 'sha256=%s\n' "${native_richedit_sha256}"
    if [[ "${native_richedit_sha256}" == "${NATIVE_RICHEDIT_SHA256}" ]]; then
        printf 'verified=yes\n'
    else
        printf 'verified=no\n'
    fi
else
    printf 'verified=missing\n'
fi

scale_factor="$(detect_system_scale_factor)"
printf '\n== scale ==\n'
printf 'system_scale=%s\n' "${scale_factor}"
printf 'wine_dpi=%s\n' "$(scale_factor_to_wine_dpi "${scale_factor}")"

printf '\n== state ==\n'
for status_file in "${STATE_DIR}"/*.status; do
    [[ -e "${status_file}" ]] || continue
    printf -- '--- %s ---\n' "${status_file}"
    sed -n '1,40p' "${status_file}"
done

printf '\n== processes ==\n'
ps -eo pid,ppid,lstart,cmd | \
    grep -E 'WXWork|wineserver|org.winehq.Wine|io.github.loveyu.WeComWine|build-portal-wine' | \
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
