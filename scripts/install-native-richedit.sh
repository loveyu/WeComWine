#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/native-richedit.status"
source_dll="${1:-}"

if [[ -z "${source_dll}" ]]; then
    printf '用法：%s /path/to/riched20.dll\n' "${0##*/}" >&2
    printf '只接受已验证的 Win2k 32 位 riched20.dll，不从仓库或网络下载。\n' >&2
    exit 64
fi
if [[ ! -f "${source_dll}" ]]; then
    printf 'RichEdit DLL 不存在：%s\n' "${source_dll}" >&2
    exit 66
fi

actual_sha256="$(sha256sum "${source_dll}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${NATIVE_RICHEDIT_SHA256}" ]]; then
    write_status "${STATUS_FILE}" "invalid-source" \
        "expected=${NATIVE_RICHEDIT_SHA256},actual=${actual_sha256}"
    printf 'RichEdit DLL 摘要不匹配。\n期望：%s\n实际：%s\n' \
        "${NATIVE_RICHEDIT_SHA256}" "${actual_sha256}" >&2
    exit 65
fi

install -d -m 0700 "${NATIVE_RICHEDIT_DIR}"
temporary_dll="$(mktemp "${NATIVE_RICHEDIT_DIR}/riched20.dll.tmp.XXXXXX")"
cleanup() {
    rm -f -- "${temporary_dll}"
}
trap cleanup EXIT

install -m 0600 "${source_dll}" "${temporary_dll}"
mv -f -- "${temporary_dll}" "${NATIVE_RICHEDIT_DLL_HOST}"
trap - EXIT

write_status "${STATUS_FILE}" "installed" \
    "path=${NATIVE_RICHEDIT_DLL_HOST},sha256=${actual_sha256}"
printf '已安装用户自备 RichEdit：%s\n' "${NATIVE_RICHEDIT_DLL_HOST}"
printf 'SHA-256：%s\n' "${actual_sha256}"
printf '下次启动将默认使用该 RichEdit；可设置 WECOM_NATIVE_RICHEDIT=0 临时回退到 Wine 内置实现。\n'
