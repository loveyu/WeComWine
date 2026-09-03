#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="${WECOM_PROJECT_DIR:-$(cd -- "${SCRIPT_DIR}/.." && pwd -P)}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
APPLICATION_DIR="${XDG_DATA_HOME}/applications"
DESKTOP_FILE="io.github.loveyu.WeComWine.desktop"
ICON_FILE="io.github.loveyu.WeComWine.png"
RUNNER_STATE_FILE="${WECOM_STATE_DIR:-${XDG_STATE_HOME}/wecom-flatpak-poc}/runner.app"
DEEPIN_FLATPAK_APP="io.github.loveyu.WeComWine.Deepin"

install -d "${APPLICATION_DIR}"
active_runner=''
if [[ -s "${RUNNER_STATE_FILE}" ]]; then
    active_runner="$(<"${RUNNER_STATE_FILE}")"
fi

if [[ "${active_runner}" == "${DEEPIN_FLATPAK_APP}" ]]; then
    # The Deepin Flatpak exports its own desktop file.  Keeping this legacy
    # systemd launcher beside it creates two menu/taskbar entries and can
    # start the same prefix for a second time.
    rm -f -- "${APPLICATION_DIR}/${DESKTOP_FILE}"
    printf 'Deepin 模式：已移除重复的 Wine Flatpak 桌面入口。\n'
else
    install -m 644 \
        "${PROJECT_DIR}/desktop/${DESKTOP_FILE}" \
        "${APPLICATION_DIR}/${DESKTOP_FILE}"
fi

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
