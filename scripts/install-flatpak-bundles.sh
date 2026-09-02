#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

main_bundle="${1:-}"
richedit_bundle="${2:-}"

if [[ -z "${main_bundle}" || ! -f "${main_bundle}" ]]; then
    printf '用法：%s MAIN.flatpak [RICHEDIT.flatpak]\n' "$0" >&2
    exit 64
fi
if [[ -n "${richedit_bundle}" && ! -f "${richedit_bundle}" ]]; then
    printf 'RichEdit Flatpak 不存在：%s\n' "${richedit_bundle}" >&2
    exit 66
fi

flatpak install --user --noninteractive -y "${main_bundle}"
if [[ -n "${richedit_bundle}" ]]; then
    flatpak install --user --noninteractive -y "${richedit_bundle}"
fi

"${PROJECT_DIR}/scripts/install-user.sh"
install -d "$(dirname -- "${RUNNER_STATE_FILE}")"
printf '%s\n' "${PORTAL_FLATPAK_APP}" > "${RUNNER_STATE_FILE}"

flatpak info --user "${PORTAL_FLATPAK_APP}//${PORTAL_FLATPAK_BRANCH}"
if [[ -n "${richedit_bundle}" ]]; then
    flatpak info --user \
        "${RICHEDIT_EXTENSION_ID}//${RICHEDIT_EXTENSION_BRANCH}"
fi

printf 'Flatpak 与用户级集成已安装。企业微信程序未包含在制品中。\n'
printf '单独安装企业微信时执行：\n'
printf '  systemctl --user start wecom-flatpak-poc-bootstrap.service\n'
