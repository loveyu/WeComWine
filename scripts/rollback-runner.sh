#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

systemctl --user stop wecom-flatpak-poc.target
flatpak kill "${PORTAL_FLATPAK_APP}" 2>/dev/null || true
flatpak kill "${DEEPIN_FLATPAK_APP}" 2>/dev/null || true
printf '%s\n' "${FLATPAK_APP}" > "${RUNNER_STATE_FILE}"
systemctl --user start --no-block wecom-flatpak-poc.target
write_status "${STATE_DIR}/portal-switch.status" "rolled-back" "${FLATPAK_APP}"
