#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
INSTALL_ROOT="${WECOM_INSTALL_ROOT:-${XDG_DATA_HOME}/wecom-wine-flatpak}"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME}/systemd/user"

install -d "${INSTALL_ROOT}" "${SYSTEMD_USER_DIR}"

for directory in desktop flatpak icons patches scripts tests; do
    cp -a "${SOURCE_ROOT}/${directory}" "${INSTALL_ROOT}/"
done

# The former KWin rule forced system borders and could leave WeCom windows at
# the topmost level.  Remove the stale installed helper during in-place
# upgrades; the source tree no longer ships or invokes it.
rm -f -- "${INSTALL_ROOT}/scripts/install-kwin-rule.sh"
"${INSTALL_ROOT}/scripts/remove-stale-kwin-rule.sh"

install -m 644 "${SOURCE_ROOT}/README.md" "${INSTALL_ROOT}/README.md"
install -m 644 "${SOURCE_ROOT}/TODO.md" "${INSTALL_ROOT}/TODO.md"
install -m 644 "${SOURCE_ROOT}/PACKAGING.md" "${INSTALL_ROOT}/PACKAGING.md"
install -m 644 "${SOURCE_ROOT}/THIRD_PARTY.md" "${INSTALL_ROOT}/THIRD_PARTY.md"
install -m 644 "${SOURCE_ROOT}/VERSION" "${INSTALL_ROOT}/VERSION"
chmod +x "${INSTALL_ROOT}"/scripts/*.sh

for unit_file in "${SOURCE_ROOT}"/systemd/*; do
    install -m 644 "${unit_file}" "${SYSTEMD_USER_DIR}/$(basename "${unit_file}")"
done

WECOM_PROJECT_DIR="${INSTALL_ROOT}" \
    "${INSTALL_ROOT}/scripts/install-user-integration.sh"
if [[ "${WECOM_SKIP_SYSTEMD_RELOAD:-0}" != "1" ]]; then
    systemctl --user daemon-reload
fi

printf '用户级文件已安装到 %s\n' "${INSTALL_ROOT}"
printf '未自动启动。首次部署请执行：\n'
printf '  systemctl --user enable --now wecom-flatpak-poc.target\n'
