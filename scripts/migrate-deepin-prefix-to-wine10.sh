#!/usr/bin/env bash

set -Eeuo pipefail

: "${WINEPREFIX:?WINEPREFIX 未设置}"

readonly engine_root="/app/deepin-wine10-stable"
readonly engine_marker="${WINEPREFIX}/.wine-engine"
readonly engine_version="deepin-wine-10.14"
readonly windows_dir="${WINEPREFIX}/drive_c/windows"
readonly backup_dir="${WINEPREFIX}/.wine10-migration-backup"

for required_path in \
    "${engine_root}/bin/wine" \
    "${engine_root}/bin/wineserver" \
    "${engine_root}/lib/wine/x86_64-unix/ntdll.so" \
    "${WINEPREFIX}/system.reg" \
    "${windows_dir}/system32" \
    "${windows_dir}/syswow64"; do
    if [[ ! -e "${required_path}" ]]; then
        printf 'Deepin Wine 10 前缀切换缺少必要文件：%s\n' \
            "${required_path}" >&2
        exit 65
    fi
done

if [[ -f "${engine_marker}" ]] && \
   [[ "$(<"${engine_marker}")" == "${engine_version}" ]]; then
    exit 0
fi

if [[ -e "${backup_dir}" ]]; then
    printf '检测到未完成的 Deepin Wine 10 前缀迁移备份，拒绝重复覆盖：%s\n' \
        "${backup_dir}" >&2
    exit 73
fi

install -d "${backup_dir}"
cp -a "${windows_dir}/system32" "${backup_dir}/system32"
cp -a "${windows_dir}/syswow64" "${backup_dir}/syswow64"
if [[ -f "${engine_marker}" ]]; then
    cp -a "${engine_marker}" "${backup_dir}/wine-engine"
fi

rollback_migration() {
    trap - ERR
    rm -rf -- "${windows_dir}/system32" "${windows_dir}/syswow64"
    cp -a "${backup_dir}/system32" "${windows_dir}/system32"
    cp -a "${backup_dir}/syswow64" "${windows_dir}/syswow64"
    if [[ -f "${backup_dir}/wine-engine" ]]; then
        cp -a "${backup_dir}/wine-engine" "${engine_marker}"
    else
        rm -f "${engine_marker}"
    fi
}
trap rollback_migration ERR

# A Wine 11 migration leaves builtin links under /app/lib/wine.  Point only
# those generated links back to the complete Deepin engine; user data and
# native application DLLs remain untouched.  The Wine 11 migration script can
# reverse this mapping if that engine is selected again later.
while IFS= read -r -d '' link_path; do
    link_target="$(readlink -- "${link_path}")"
    case "${link_target}" in
        /app/lib/wine/*)
            relative_target="${link_target#/app/lib/wine/}"
            ln -sfn "${engine_root}/lib/wine/${relative_target}" \
                "${link_path}"
            ;;
        /opt/deepin-wine10-stable/*)
            relative_target="${link_target#/opt/deepin-wine10-stable/}"
            ln -sfn "${engine_root}/${relative_target}" "${link_path}"
            ;;
    esac
done < <(find "${windows_dir}/system32" "${windows_dir}/syswow64" \
    -type l -print0)

rm -f "${windows_dir}/system32/winedbg.exe" \
    "${windows_dir}/syswow64/winedbg.exe"
printf '%s\n' "${engine_version}" > "${engine_marker}"
trap - ERR

printf '企业微信前缀已切换到 %s；Wine 11 系统目录备份已保留。\n' \
    "${engine_version}"
