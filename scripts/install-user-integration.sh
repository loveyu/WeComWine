#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="${WECOM_PROJECT_DIR:-$(cd -- "${SCRIPT_DIR}/.." && pwd -P)}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
APPLICATION_DIR="${XDG_DATA_HOME}/applications"
DESKTOP_FILE="io.github.loveyu.WeComWine.desktop"

install -d "${APPLICATION_DIR}"
install -m 644 \
    "${PROJECT_DIR}/desktop/${DESKTOP_FILE}" \
    "${APPLICATION_DIR}/${DESKTOP_FILE}"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APPLICATION_DIR}" >/dev/null 2>&1 || true
fi
