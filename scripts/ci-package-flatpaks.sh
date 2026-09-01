#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

export WECOM_FLATPAK_REMOTE="${WECOM_FLATPAK_REMOTE:-flathub-wecom}"
export WECOM_FLATPAK_REMOTE_URL="${WECOM_FLATPAK_REMOTE_URL:-https://dl.flathub.org/repo/}"
export WECOM_PORTAL_FLATPAK_REPO="${WECOM_PORTAL_FLATPAK_REPO:-${PROJECT_DIR}/artifacts/repo}"
export WECOM_MAIN_FLATPAK_REPO="${WECOM_PORTAL_FLATPAK_REPO}"
export WECOM_FLATPAK_OUTPUT_DIR="${WECOM_FLATPAK_OUTPUT_DIR:-${PROJECT_DIR}/artifacts/flatpak}"

for command_name in flatpak curl patch make gcc git; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'CI 节点缺少命令：%s\n' "${command_name}" >&2
        exit 69
    fi
done

flatpak remote-add --user --if-not-exists \
    "${WECOM_FLATPAK_REMOTE}" \
    "${WECOM_FLATPAK_REMOTE_URL}"

cd -- "${PROJECT_DIR}"
make check
BUILD_JOBS="${BUILD_JOBS:-4}" "${SCRIPT_DIR}/build-portal-wine.sh"
"${SCRIPT_DIR}/package-flatpaks.sh"
make dist SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
