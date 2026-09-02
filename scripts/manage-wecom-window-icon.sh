#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

load_desktop_environment

for command_name in python3 magick; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf '企业微信窗口图标管理器已禁用：宿主缺少 %s\n' \
            "${command_name}" >&2
        exit 69
    fi
done

exec python3 "${SCRIPT_DIR}/manage-wecom-window-icon.py" "$@"
