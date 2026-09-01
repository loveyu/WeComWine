#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

if [[ "${ACTIVE_FLATPAK_APP}" != "${PORTAL_FLATPAK_APP}" ]]; then
    exit 0
fi

if [[ -f "${NATIVE_RICHEDIT_DLL_HOST}" ]]; then
    actual_sha256="$(sha256sum "${NATIVE_RICHEDIT_DLL_HOST}" | awk '{print $1}')"
    if [[ "${actual_sha256}" == "${NATIVE_RICHEDIT_SHA256}" ]]; then
        exit 0
    fi
fi

if ! flatpak info --user \
    "${RICHEDIT_EXTENSION_ID}//${RICHEDIT_EXTENSION_BRANCH}" >/dev/null 2>&1; then
    exit 0
fi

install -d -m 700 "${NATIVE_RICHEDIT_DIR}"
stage_file="${NATIVE_RICHEDIT_DLL_HOST}.extension.$$"

cleanup() {
    rm -f -- "${stage_file}"
}
trap cleanup EXIT

flatpak run \
    --command=sh \
    --filesystem="${NATIVE_RICHEDIT_DIR}" \
    "${PORTAL_FLATPAK_APP}//${PORTAL_FLATPAK_BRANCH}" \
    -c '
        set -eu
        source_file=/app/share/wecom-richedit/riched20.dll
        expected_sha256="$1"
        destination="$2"
        test -r "${source_file}"
        actual_sha256="$(sha256sum "${source_file}")"
        actual_sha256="${actual_sha256%% *}"
        test "${actual_sha256}" = "${expected_sha256}"
        cp "${source_file}" "${destination}"
        chmod 600 "${destination}"
    ' sh "${NATIVE_RICHEDIT_SHA256}" "${stage_file}"

actual_sha256="$(sha256sum "${stage_file}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${NATIVE_RICHEDIT_SHA256}" ]]; then
    printf 'RichEdit 扩展摘要不匹配：expected=%s actual=%s\n' \
        "${NATIVE_RICHEDIT_SHA256}" "${actual_sha256}" >&2
    exit 65
fi

mv -f -- "${stage_file}" "${NATIVE_RICHEDIT_DLL_HOST}"
chmod 600 "${NATIVE_RICHEDIT_DLL_HOST}"
printf '已从 Flatpak 扩展同步 RichEdit：%s\n' "${NATIVE_RICHEDIT_DLL_HOST}"
