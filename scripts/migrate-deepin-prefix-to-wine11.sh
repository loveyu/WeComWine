#!/usr/bin/env bash

set -Eeuo pipefail

: "${WINEPREFIX:?WINEPREFIX 未设置}"

readonly engine_marker="${WINEPREFIX}/.wine-engine"
readonly engine_version="wine-11.0-portal"
readonly windows_dir="${WINEPREFIX}/drive_c/windows"
readonly backup_dir="${WINEPREFIX}/.wine11-migration-backup"
readonly wine10_backup_dir="${WINEPREFIX}/.wine10-migration-backup"
readonly font_source="/app/share/fonts/truetype/wqy/wqy-microhei.ttc"

remove_legacy_renderer_override() {
    local cleaned_user_reg="${WINEPREFIX}/user.reg.wine11-clean"

    if ! grep -Fq \
        '[Software\\Wine\\AppDefaults\\WXWorkWeb.exe\\Direct3D]' \
        "${WINEPREFIX}/user.reg"; then
        return 0
    fi

    /app/bin/wineserver -k >/dev/null 2>&1 || true
    awk '
        /^\[Software\\\\Wine\\\\AppDefaults\\\\WXWorkWeb\.exe\\\\Direct3D\][[:space:]]/ {
            skip_section = 1
            next
        }
        skip_section && /^$/ {
            skip_section = 0
            next
        }
        !skip_section { print }
    ' "${WINEPREFIX}/user.reg" > "${cleaned_user_reg}"
    mv "${cleaned_user_reg}" "${WINEPREFIX}/user.reg"
}

remap_legacy_builtin_links() {
    local link_path=''
    local link_target=''
    local relative_target=''

    while IFS= read -r -d '' link_path; do
        link_target="$(readlink -- "${link_path}")"
        case "${link_target}" in
            /opt/deepin-wine10-stable/*)
                relative_target="${link_target#/opt/deepin-wine10-stable/}"
                ;;
            /app/deepin-wine10-stable/*)
                relative_target="${link_target#/app/deepin-wine10-stable/}"
                ;;
            *)
                continue
                ;;
        esac
        ln -sfn "/app/${relative_target}" "${link_path}"
    done < <(find "${windows_dir}/system32" "${windows_dir}/syswow64" \
        -type l -print0)
}

if [[ -f "${engine_marker}" ]] && \
   [[ "$(<"${engine_marker}")" == "${engine_version}" ]]; then
    remove_legacy_renderer_override
    exit 0
fi

# The complete Deepin Wine 10 switch keeps an exact copy of the preceding
# Wine 11 system directories.  Restore that copy before entering the original
# first-time migration path; the historical Deepin 10 backup directories can
# then remain untouched.
if [[ -f "${engine_marker}" ]] && \
   [[ "$(<"${engine_marker}")" == "deepin-wine-10.14" ]] && \
   [[ -d "${wine10_backup_dir}/system32" ]] && \
   [[ -d "${wine10_backup_dir}/syswow64" ]] && \
   [[ -f "${wine10_backup_dir}/wine-engine" ]]; then
    /app/deepin-wine10-stable/bin/wineserver -k >/dev/null 2>&1 || true
    rm -rf -- "${windows_dir}/system32" "${windows_dir}/syswow64"
    cp -a "${wine10_backup_dir}/system32" "${windows_dir}/system32"
    cp -a "${wine10_backup_dir}/syswow64" "${windows_dir}/syswow64"
    cp -a "${wine10_backup_dir}/wine-engine" "${engine_marker}"
    remove_legacy_renderer_override
    printf '企业微信前缀已恢复到 %s。\n' "${engine_version}"
    exit 0
fi

for required_path in \
    "${WINEPREFIX}/system.reg" \
    "${WINEPREFIX}/user.reg" \
    "${windows_dir}/system32" \
    "${windows_dir}/syswow64" \
    "${font_source}"; do
    if [[ ! -e "${required_path}" ]]; then
        printf 'Wine 11 前缀迁移缺少必要文件：%s\n' "${required_path}" >&2
        exit 65
    fi
done

if [[ -e "${windows_dir}/system32.deepin-10.14-backup" ||
      -e "${windows_dir}/syswow64.deepin-10.14-backup" ||
      -e "${backup_dir}" ]]; then
    printf '检测到未完成的 Wine 11 前缀迁移备份，拒绝重复覆盖：%s\n' \
        "${WINEPREFIX}" >&2
    exit 73
fi

install -d "${backup_dir}"
for registry_file in system.reg user.reg userdef.reg; do
    if [[ -f "${WINEPREFIX}/${registry_file}" ]]; then
        cp -a "${WINEPREFIX}/${registry_file}" "${backup_dir}/${registry_file}"
    fi
done
cp -a "${windows_dir}/system32" \
    "${windows_dir}/system32.deepin-10.14-backup"
cp -a "${windows_dir}/syswow64" \
    "${windows_dir}/syswow64.deepin-10.14-backup"

rollback_migration() {
    local registry_file=''

    /app/bin/wineserver -k >/dev/null 2>&1 || true
    rm -rf -- "${windows_dir}/system32" "${windows_dir}/syswow64"
    mv "${windows_dir}/system32.deepin-10.14-backup" \
        "${windows_dir}/system32"
    mv "${windows_dir}/syswow64.deepin-10.14-backup" \
        "${windows_dir}/syswow64"
    for registry_file in system.reg user.reg userdef.reg; do
        if [[ -f "${backup_dir}/${registry_file}" ]]; then
            cp -a "${backup_dir}/${registry_file}" \
                "${WINEPREFIX}/${registry_file}"
        fi
    done
    rm -rf -- "${backup_dir}"
}
trap rollback_migration ERR

# Wine must be able to load the old prefix's kernel32 before wineboot can
# upgrade it. Repoint both historical Deepin paths to Wine 11 first, while the
# untouched system-directory copies remain available for rollback.
remap_legacy_builtin_links

# Disable the optional Mono/MSHTML installers during the in-place engine
# conversion. They are not used by WeCom and would otherwise show an
# unattended installer prompt.
WINEPREDLL= WINEDLLOVERRIDES='mscoree,mshtml=' \
    /app/bin/wineboot -u

install -m 0644 "${font_source}" \
    "${windows_dir}/Fonts/wqy-microhei.ttc"
/app/bin/wine reg add \
    'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
    /v 'WenQuanYi Micro Hei (TrueType)' /t REG_SZ \
    /d 'wqy-microhei.ttc' /f >/dev/null

# This registry value is specific to Deepin Wine 10 and prevents ANGLE from
# selecting a renderer under Wine 11. Wine's reg.exe reports success without
# removing this legacy AppDefaults section, so remove that one section offline.
remove_legacy_renderer_override

rm -f "${windows_dir}/system32/winedbg.exe" \
    "${windows_dir}/syswow64/winedbg.exe"
printf '%s\n' "${engine_version}" > "${engine_marker}"
rm -rf -- "${backup_dir}"
trap - ERR

printf '企业微信前缀已迁移到 %s；Deepin 系统目录备份已保留。\n' \
    "${engine_version}"
