#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="${WECOM_PROJECT_DIR:-$(cd -- "${SCRIPT_DIR}/.." && pwd -P)}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
APPLICATION_DIR="${XDG_DATA_HOME}/applications"
DESKTOP_FILE="io.github.loveyu.WeComWine.desktop"
ICON_FILE="io.github.loveyu.WeComWine.png"

install -d "${APPLICATION_DIR}"
install -m 644 \
    "${PROJECT_DIR}/desktop/${DESKTOP_FILE}" \
    "${APPLICATION_DIR}/${DESKTOP_FILE}"

for source_icon in "${PROJECT_DIR}"/icons/hicolor/*/apps/"${ICON_FILE}"; do
    icon_size="$(basename "$(dirname "$(dirname "${source_icon}")")")"
    icon_dir="${XDG_DATA_HOME}/icons/hicolor/${icon_size}/apps"
    install -d "${icon_dir}"
    install -m 644 "${source_icon}" "${icon_dir}/${ICON_FILE}"
done

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APPLICATION_DIR}" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache --force "${XDG_DATA_HOME}/icons/hicolor" >/dev/null 2>&1 || true
fi
