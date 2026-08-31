#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/bootstrap.status"
LOCK_FILE="${STATE_DIR}/bootstrap.lock"
LOG_FILE="${LOG_DIR}/bootstrap.log"

rotate_log "${LOG_FILE}"
exec >> "${LOG_FILE}" 2>&1
exec 9> "${LOCK_FILE}"

if ! flock -n 9; then
    printf '%s bootstrap already running\n' "$(date --iso-8601=seconds)"
    exit 0
fi

on_error() {
    local exit_code="$?"
    local line_number="${BASH_LINENO[0]:-unknown}"

    write_status "${STATUS_FILE}" "failed" "exit=${exit_code},line=${line_number}"
    printf '%s bootstrap failed: exit=%s line=%s\n' \
        "$(date --iso-8601=seconds)" "${exit_code}" "${line_number}"
    exit "${exit_code}"
}

trap on_error ERR

printf '%s bootstrap start\n' "$(date --iso-8601=seconds)"

write_status "${STATUS_FILE}" "install-flatpak" "${FLATPAK_REF}"
if ! flatpak remotes --user --columns=name | grep -Fxq "${FLATPAK_REMOTE}"; then
    flatpak remote-add \
        --user \
        --if-not-exists \
        --gpg-import="${FLATPAK_GPG_KEY}" \
        "${FLATPAK_REMOTE}" \
        "${FLATPAK_REMOTE_URL}"
fi
flatpak remote-modify --user --url="${FLATPAK_REMOTE_URL}" "${FLATPAK_REMOTE}"

if ! flatpak info --user "${FLATPAK_REF}" >/dev/null 2>&1; then
    flatpak install --user --noninteractive -y --no-deps --no-related \
        "${FLATPAK_REMOTE}" "${FLATPAK_REF}"
fi
flatpak info --user "${FLATPAK_REF}"

for extension_ref in "${FLATPAK_GECKO_REF}" "${FLATPAK_MONO_REF}"; do
    if ! flatpak info --user "${extension_ref}" >/dev/null 2>&1; then
        flatpak install --user --noninteractive -y --no-deps --no-related \
            "${FLATPAK_REMOTE}" "${extension_ref}"
    fi
done

write_status "${STATUS_FILE}" "download-installer" "${WECOM_VERSION}"
if [[ -f "${WECOM_INSTALLER_HOST}" ]]; then
    actual_sha256="$(sha256sum "${WECOM_INSTALLER_HOST}" | awk '{print $1}')"
    if [[ "${actual_sha256}" != "${WECOM_SHA256}" ]]; then
        quarantine_path="${WECOM_INSTALLER_HOST}.invalid.$(date +%s)"
        mv "${WECOM_INSTALLER_HOST}" "${quarantine_path}"
        printf 'moved invalid installer to %s\n' "${quarantine_path}"
    fi
fi

if [[ ! -f "${WECOM_INSTALLER_HOST}" ]]; then
    curl \
        --fail \
        --location \
        --continue-at - \
        --retry 20 \
        --retry-all-errors \
        --retry-delay 10 \
        --connect-timeout 30 \
        --output "${WECOM_INSTALLER_HOST}" \
        "${WECOM_URL}"
fi

actual_sha256="$(sha256sum "${WECOM_INSTALLER_HOST}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${WECOM_SHA256}" ]]; then
    printf 'installer SHA-256 mismatch: expected=%s actual=%s\n' \
        "${WECOM_SHA256}" "${actual_sha256}"
    exit 2
fi

write_status "${STATUS_FILE}" "initialize-prefix" "${WINEPREFIX_SANDBOX}"
if [[ "${ACTIVE_FLATPAK_APP}" == "${PORTAL_FLATPAK_APP}" ]]; then
    flatpak_wine sh /app/share/wecom-portal-tests/configure-prefix.sh
else
    flatpak_wine wineboot --update
    flatpak_wine wineserver --wait
    flatpak_wine winecfg -v win10
    flatpak_wine wine reg.exe add 'HKCU\Software\Wine\X11 Driver' /v UseXIM /t REG_SZ /d Y /f
    flatpak_wine wine reg.exe add 'HKCU\Software\Wine\X11 Driver' /v InputStyle /t REG_SZ /d overthespot /f
    flatpak_wine wineserver --wait
fi

program_host="$(find "${WINEPREFIX_HOST}/drive_c" -type f -iname 'WXWork.exe' -print -quit 2>/dev/null || true)"
if [[ -z "${program_host}" ]]; then
    write_status "${STATUS_FILE}" "install-wecom" "${WECOM_VERSION}"
    flatpak_wine wine "${WECOM_INSTALLER_HOST}" /S
    flatpak_wine wineserver --wait
    program_host="$(find "${WINEPREFIX_HOST}/drive_c" -type f -iname 'WXWork.exe' -print -quit 2>/dev/null || true)"
fi

if [[ -z "${program_host}" ]]; then
    printf 'WXWork.exe was not found below %s\n' "${WINEPREFIX_HOST}/drive_c"
    exit 3
fi

program_relative="${program_host#"${WINEPREFIX_HOST}/drive_c/"}"
program_windows="C:\\$(printf '%s' "${program_relative}" | tr '/' '\\')"
printf '%s\n' "${program_windows}" > "${STATE_DIR}/program.path"
printf '%s\n' "${program_host}" > "${STATE_DIR}/program.host-path"

"${PROJECT_DIR}/scripts/install-user-integration.sh"

flatpak kill "${ACTIVE_FLATPAK_APP}" 2>/dev/null || true
write_status "${STATUS_FILE}" "complete" "${program_windows}"
printf '%s bootstrap complete: %s\n' "$(date --iso-8601=seconds)" "${program_windows}"
