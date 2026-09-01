#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

VERSION="$(tr -d '[:space:]' < "${PROJECT_DIR}/VERSION")"
OUTPUT_DIR="${WECOM_FLATPAK_OUTPUT_DIR:-${PROJECT_DIR}/artifacts/flatpak}"
MAIN_REPO="${WECOM_MAIN_FLATPAK_REPO:-${PORTAL_FLATPAK_REPO}}"
RUNTIME_REPO_URL="${WECOM_RUNTIME_REPO_URL:-https://dl.flathub.org/repo/flathub.flatpakrepo}"
RICHEDIT_DLL="${WECOM_RICHEDIT_DLL:-}"
REQUIRE_RICHEDIT="${WECOM_REQUIRE_RICHEDIT_PACKAGE:-0}"

for command_name in flatpak sha256sum install mktemp; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf '缺少打包命令：%s\n' "${command_name}" >&2
        exit 69
    fi
done

if [[ ! -d "${MAIN_REPO}" ]]; then
    printf 'Flatpak 主仓库不存在：%s\n' "${MAIN_REPO}" >&2
    exit 66
fi

install -d "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd -- "${OUTPUT_DIR}" && pwd -P)"
main_bundle="${OUTPUT_DIR}/${PORTAL_FLATPAK_APP}-${VERSION}-x86_64.flatpak"
richedit_bundle="${OUTPUT_DIR}/${RICHEDIT_EXTENSION_ID}-${VERSION}-x86_64.flatpak"
checksums_file="${OUTPUT_DIR}/SHA256SUMS"

rm -f -- "${main_bundle}" "${richedit_bundle}" "${checksums_file}"
flatpak build-bundle \
    --runtime-repo="${RUNTIME_REPO_URL}" \
    "${MAIN_REPO}" "${main_bundle}" \
    "${PORTAL_FLATPAK_APP}" "${PORTAL_FLATPAK_BRANCH}"

if [[ -n "${RICHEDIT_DLL}" ]]; then
    "${SCRIPT_DIR}/package-richedit-extension.sh" \
        "${RICHEDIT_DLL}" "${richedit_bundle}"
elif [[ "${REQUIRE_RICHEDIT}" == "1" ]]; then
    printf '要求生成 RichEdit 扩展，但未设置 WECOM_RICHEDIT_DLL。\n' >&2
    exit 64
else
    printf '未提供 WECOM_RICHEDIT_DLL，仅生成主 Flatpak。\n'
fi

(
    cd -- "${OUTPUT_DIR}"
    sha256sum "$(basename -- "${main_bundle}")" > "${checksums_file}"
    if [[ -f "${richedit_bundle}" ]]; then
        sha256sum "$(basename -- "${richedit_bundle}")" >> "${checksums_file}"
    fi
)

printf 'Flatpak 制品目录：%s\n' "${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"/*.flatpak "${checksums_file}"
