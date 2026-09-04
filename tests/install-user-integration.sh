#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

application_dir="${TEST_ROOT}/data/applications"
stale_desktop="${application_dir}/io.github.loveyu.WeComWine.Deepin.desktop"
install -d "${application_dir}"
cp "${PROJECT_DIR}/desktop/io.github.loveyu.WeComWine.Deepin.desktop" \
    "${stale_desktop}"
printf '%s\n' 'X-Flatpak=io.github.loveyu.WeComWine.Deepin' >> "${stale_desktop}"
sed -i 's|^Exec=.*|Exec=/usr/bin/flatpak run --branch=stable-25.08 io.github.loveyu.WeComWine.Deepin|' \
    "${stale_desktop}"

XDG_DATA_HOME="${TEST_ROOT}/data" \
XDG_STATE_HOME="${TEST_ROOT}/state" \
WECOM_PROJECT_DIR="${PROJECT_DIR}" \
    bash "${PROJECT_DIR}/scripts/install-user-integration.sh" \
    > "${TEST_ROOT}/install.log"

[[ ! -e "${stale_desktop}" ]]
grep -Fq '已移除覆盖 Flatpak 导出项的旧 Deepin 桌面入口。' \
    "${TEST_ROOT}/install.log"
[[ -f "${application_dir}/io.github.loveyu.WeComWine.desktop" ]]

custom_desktop="${application_dir}/io.github.loveyu.WeComWine.Deepin.desktop"
printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=User-defined launcher' \
    'Exec=/usr/bin/true' > "${custom_desktop}"

XDG_DATA_HOME="${TEST_ROOT}/data" \
XDG_STATE_HOME="${TEST_ROOT}/state" \
WECOM_PROJECT_DIR="${PROJECT_DIR}" \
    bash "${PROJECT_DIR}/scripts/install-user-integration.sh" \
    > "${TEST_ROOT}/install-custom.log"

grep -Fq 'Name=User-defined launcher' "${custom_desktop}"
