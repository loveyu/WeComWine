#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/cef-compat.status"
wxwork_root="${WECOM_CEF_ROOT:-${WINEPREFIX_HOST}/drive_c/Program Files (x86)/WXWork}"
enabled="${WECOM_CEF_COMPAT_PATCH:-1}"

if [[ "${enabled}" != "0" && "${enabled}" != "1" ]]; then
    write_status "${STATUS_FILE}" "invalid-setting" \
        "WECOM_CEF_COMPAT_PATCH=${enabled}"
    printf 'WECOM_CEF_COMPAT_PATCH 只允许 0 或 1，当前值：%s\n' \
        "${enabled}" >&2
    exit 64
fi

if [[ "${enabled}" == "0" ]]; then
    write_status "${STATUS_FILE}" "disabled" "WECOM_CEF_COMPAT_PATCH=0"
    exit 0
fi

if [[ ! -d "${wxwork_root}" ]]; then
    write_status "${STATUS_FILE}" "not-installed" "root=${wxwork_root}"
    exit 0
fi

mapfile -d '' cef_candidates < <(
    find "${wxwork_root}" -mindepth 3 -maxdepth 3 -type f \
        -path '*/compatible_web/libcef.dll' -print0 | sort -zV
)
if (( ${#cef_candidates[@]} == 0 )); then
    write_status "${STATUS_FILE}" "not-found" "root=${wxwork_root}"
    exit 0
fi

# The updater can retain an older version directory.  Only patch the newest
# installed CEF; the launcher selects the same newest WXWork version.
cef_dll="${cef_candidates[${#cef_candidates[@]} - 1]}"
cef_sha256="$(sha256sum "${cef_dll}" | awk '{print $1}')"

# CEF 107 protects the first .data page and then asserts that VirtualProtect
# returned PAGE_READWRITE as the old protection.  Wine can correctly return
# PAGE_WRITECOPY for the image mapping, which sends the renderer to an int3.
# Match the complete instruction shape around the assertion, require one
# unique occurrence, and patch only its conditional branch.  Relocation/IAT
# addresses and branch displacements are intentionally treated as variables
# so a normal WeCom update is not blocked by a fixed binary hash.
scan_output="$(LC_ALL=C perl -0777 -e '
    use strict;
    use warnings;

    my ($path) = @ARGV;
    open my $fh, "<:raw", $path or die "open $path: $!\n";
    local $/;
    my $data = <$fh>;
    close $fh;

    while ($data =~ /\x68....\xff\x15....\x85\xc0\x0f\x84....\x83\xbd\x2c\xff\xff\xff\x04(?:\x0f\x85....|\x90{6})\xff\x15..../sg) {
        my $branch_offset = $-[0] + 26;
        my $branch = substr($data, $branch_offset, 6);
        my $kind = $branch eq ("\x90" x 6) ? "patched" : "original";
        print "$kind:$branch_offset\n";
    }
' "${cef_dll}")"

matches=()
if [[ -n "${scan_output}" ]]; then
    mapfile -t matches <<< "${scan_output}"
fi
if (( ${#matches[@]} != 1 )); then
    write_status "${STATUS_FILE}" "unsupported" \
        "path=${cef_dll},sha256=${cef_sha256},matches=${#matches[@]}"
    printf 'CEF 兼容补丁未修改未知指令布局：%s（匹配数 %s）\n' \
        "${cef_dll}" "${#matches[@]}" >&2
    exit 0
fi

match_kind="${matches[0]%%:*}"
branch_offset="${matches[0]#*:}"
if [[ ! "${branch_offset}" =~ ^[0-9]+$ ]]; then
    write_status "${STATUS_FILE}" "scan-error" "result=${matches[0]}"
    exit 70
fi

if [[ "${match_kind}" == "patched" ]]; then
    write_status "${STATUS_FILE}" "patched" \
        "path=${cef_dll},sha256=${cef_sha256},offset=${branch_offset}"
    exit 0
fi
if [[ "${match_kind}" != "original" ]]; then
    write_status "${STATUS_FILE}" "scan-error" "result=${matches[0]}"
    exit 70
fi

backup="${cef_dll}.wecomwine-backup-${cef_sha256:0:16}"
if [[ -e "${backup}" ]]; then
    backup_sha256="$(sha256sum "${backup}" | awk '{print $1}')"
    if [[ "${backup_sha256}" != "${cef_sha256}" ]]; then
        write_status "${STATUS_FILE}" "backup-conflict" \
            "path=${backup},expected=${cef_sha256},actual=${backup_sha256}"
        printf 'CEF 原始备份摘要冲突，拒绝修改：%s\n' "${backup}" >&2
        exit 74
    fi
else
    cp --preserve=all -- "${cef_dll}" "${backup}"
fi

printf '\220\220\220\220\220\220' | dd of="${cef_dll}" bs=1 \
    seek="${branch_offset}" conv=notrunc status=none

patched_bytes="$(dd if="${cef_dll}" bs=1 skip="${branch_offset}" count=6 \
    status=none | od -An -tx1 | tr -d ' \n')"
if [[ "${patched_bytes}" != "909090909090" ]]; then
    cp --preserve=all -- "${backup}" "${cef_dll}"
    write_status "${STATUS_FILE}" "verify-failed-restored" \
        "path=${cef_dll},offset=${branch_offset},bytes=${patched_bytes}"
    printf 'CEF 补丁校验失败，已恢复原文件：%s\n' "${cef_dll}" >&2
    exit 74
fi

patched_sha256="$(sha256sum "${cef_dll}" | awk '{print $1}')"
write_status "${STATUS_FILE}" "patched" \
    "path=${cef_dll},sha256=${patched_sha256},offset=${branch_offset},backup=${backup}"
printf '%s patched WeCom CEF old-protection assertion path=%s offset=%s\n' \
    "$(date --iso-8601=seconds)" "${cef_dll}" "${branch_offset}"
