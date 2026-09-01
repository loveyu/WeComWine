#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/native-richedit.status"
require_native="${WECOM_REQUIRE_NATIVE_RICHEDIT:-0}"

if [[ "${WECOM_NATIVE_RICHEDIT:-1}" == "0" ]]; then
    write_status "${STATUS_FILE}" "disabled" "WECOM_NATIVE_RICHEDIT=0"
    exec "${SCRIPT_DIR}/run-wecom.sh"
fi

if flatpak info --user "${RICHEDIT_EXTENSION_ID}//${RICHEDIT_EXTENSION_BRANCH}" \
    >/dev/null 2>&1; then
    if ! "${SCRIPT_DIR}/sync-native-richedit-extension.sh"; then
        printf 'RichEdit Flatpak 扩展同步失败，将按已安装组件状态继续。\n' >&2
    fi
fi

if [[ ! -f "${NATIVE_RICHEDIT_DLL_HOST}" ]]; then
    write_status "${STATUS_FILE}" "missing" "path=${NATIVE_RICHEDIT_DLL_HOST}"
    printf '未配置原生 RichEdit，外部图片粘贴可能不可用：%s\n' \
        "${NATIVE_RICHEDIT_DLL_HOST}" >&2
    if [[ "${require_native}" == "1" ]]; then
        exit 78
    fi
    exec "${SCRIPT_DIR}/run-wecom.sh"
fi

actual_sha256="$(sha256sum "${NATIVE_RICHEDIT_DLL_HOST}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${NATIVE_RICHEDIT_SHA256}" ]]; then
    write_status "${STATUS_FILE}" "invalid-installed" \
        "expected=${NATIVE_RICHEDIT_SHA256},actual=${actual_sha256}"
    printf '拒绝加载摘要不匹配的原生 RichEdit：%s\n' \
        "${NATIVE_RICHEDIT_DLL_HOST}" >&2
    if [[ "${require_native}" == "1" ]]; then
        exit 78
    fi
    exec "${SCRIPT_DIR}/run-wecom.sh"
fi

write_status "${STATUS_FILE}" "enabled" \
    "path=${NATIVE_RICHEDIT_DLL_HOST},sha256=${actual_sha256}"
exec "${SCRIPT_DIR}/run-wecom-native-richedit.sh"
