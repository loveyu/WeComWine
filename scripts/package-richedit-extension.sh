#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

source_dll="${1:-}"
output_bundle="${2:-}"

if [[ -z "${source_dll}" || ! -f "${source_dll}" ]]; then
    printf '用法：%s /path/to/riched20.dll OUTPUT.flatpak\n' "$0" >&2
    exit 64
fi
if [[ -z "${output_bundle}" ]]; then
    printf '必须指定 RichEdit Flatpak 输出路径。\n' >&2
    exit 64
fi

for command_name in flatpak install mkdir mktemp sha256sum; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf '缺少 RichEdit 打包命令：%s\n' "${command_name}" >&2
        exit 69
    fi
done

actual_sha256="$(sha256sum "${source_dll}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${NATIVE_RICHEDIT_SHA256}" ]]; then
    printf 'RichEdit 摘要不匹配：expected=%s actual=%s\n' \
        "${NATIVE_RICHEDIT_SHA256}" "${actual_sha256}" >&2
    exit 65
fi

mkdir -p "$(dirname -- "${output_bundle}")"
output_bundle="$(cd -- "$(dirname -- "${output_bundle}")" && pwd -P)/$(basename -- "${output_bundle}")"
rm -f -- "${output_bundle}"
extension_temp="$(mktemp -d "${TMPDIR:-/tmp}/wecom-richedit-flatpak.XXXXXX")"

cleanup() {
    rm -rf -- "${extension_temp}"
}
trap cleanup EXIT

extension_build="${extension_temp}/build"
extension_repo="${extension_temp}/repo"
install -d "${extension_build}/files" "${extension_repo}"
install -m 644 "${source_dll}" "${extension_build}/files/riched20.dll"
install -m 644 \
    "${PROJECT_DIR}/flatpak/io.github.loveyu.WeComWine.RichEdit.metadata" \
    "${extension_build}/metadata"

flatpak build-export \
    --runtime \
    --disable-fsync \
    --files=files \
    --subject="Optional user-supplied RichEdit compatibility extension" \
    "${extension_repo}" "${extension_build}" \
    "${RICHEDIT_EXTENSION_BRANCH}"
flatpak build-bundle \
    --runtime \
    "${extension_repo}" "${output_bundle}" \
    "${RICHEDIT_EXTENSION_ID}" "${RICHEDIT_EXTENSION_BRANCH}"

printf '已生成用户自备 RichEdit 扩展：%s\n' "${output_bundle}"
sha256sum "${output_bundle}"
