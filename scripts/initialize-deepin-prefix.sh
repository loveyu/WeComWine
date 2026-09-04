#!/usr/bin/env bash

set -Eeuo pipefail

: "${WINEPREFIX:?WINEPREFIX 未设置}"

readonly package_version="5.0.0.6008deepin8"
readonly archive="/app/share/wecom-deepin/adapter/files.7z"
readonly expected_exe_sha256="477ac04a7e63d915f44702861f557336528dbef2060b18b8a7b9367fd9da0654"
readonly program_relative="drive_c/Program Files (x86)/WXWork/WXWork.exe"
readonly marker="${WINEPREFIX}/.deepin-wecom-package"

if [[ -f "${marker}" ]] && [[ "$(<"${marker}")" == "${package_version}" ]] && \
   [[ -f "${WINEPREFIX}/${program_relative}" ]]; then
    exit 0
fi

if [[ -e "${WINEPREFIX}" ]]; then
    printf 'Deepin 企业微信前缀已存在但不是完整的 %s：%s\n' \
        "${package_version}" "${WINEPREFIX}" >&2
    printf '为避免混用其他安装包，拒绝覆盖。\n' >&2
    exit 73
fi
if [[ ! -f "${archive}" ]]; then
    printf 'Flatpak 中缺少 Deepin 官方企业微信代码包：%s\n' "${archive}" >&2
    exit 65
fi
if [[ ! "${USER:-}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf '无法安全写入 Wine 用户名：%s\n' "${USER:-<empty>}" >&2
    exit 65
fi

prepare_prefix="${WINEPREFIX}.prepare.$$"
cleanup_prepare() {
    if [[ -e "${prepare_prefix}" ]]; then
        rm -rf -- "${prepare_prefix}"
    fi
}
trap cleanup_prepare EXIT

install -d "${prepare_prefix}"
bsdtar -xf "${archive}" -C "${prepare_prefix}"

if [[ ! -f "${prepare_prefix}/system.reg" ]] || \
   [[ ! -f "${prepare_prefix}/user.reg" ]] || \
   [[ ! -f "${prepare_prefix}/${program_relative}" ]]; then
    printf 'Deepin 官方预制前缀解包不完整。\n' >&2
    exit 65
fi

actual_exe_sha256="$(sha256sum "${prepare_prefix}/${program_relative}" | awk '{print $1}')"
if [[ "${actual_exe_sha256}" != "${expected_exe_sha256}" ]]; then
    printf 'Deepin 企业微信主程序摘要不匹配：%s\n' "${actual_exe_sha256}" >&2
    exit 65
fi

if [[ -d "${prepare_prefix}/drive_c/users/@current_user@" ]]; then
    mv "${prepare_prefix}/drive_c/users/@current_user@" \
        "${prepare_prefix}/drive_c/users/${USER}"
fi
for registry_file in \
    "${prepare_prefix}/system.reg" \
    "${prepare_prefix}/user.reg" \
    "${prepare_prefix}/userdef.reg"; do
    if [[ -f "${registry_file}" ]]; then
        sed -i "s/@current_user@/${USER}/g" "${registry_file}"
    fi
done

# Deepin's stock Wine prefix enables AeDebug and points it at WineDbg.  The
# account must never be run under a debugger, including automatic post-crash
# attachment, so disable both 64-bit and Wow6432Node entries offline before
# Wine sees this prefix.
nodebug_registry="${prepare_prefix}/system.reg.nodebug"
awk '
    /^\[Software\\\\(Wow6432Node\\\\)?Microsoft\\\\Windows NT\\\\CurrentVersion\\\\AeDebug\][[:space:]]/ {
        in_aedebug = 1
    }
    in_aedebug && /^$/ { in_aedebug = 0 }
    in_aedebug && /^"Auto"=/ { $0 = "\"Auto\"=\"0\"" }
    in_aedebug && /^"Debugger"=/ { $0 = "\"Debugger\"=\"\"" }
    { print }
' "${prepare_prefix}/system.reg" > "${nodebug_registry}"
mv "${nodebug_registry}" "${prepare_prefix}/system.reg"

# The official prefix was built for /opt/deepin-wine10-stable.  Keep its
# builtin links on the complete engine shipped at the matching Flatpak path.
# c:, z: and device mappings keep their original targets.
while IFS= read -r -d '' link_path; do
    link_target="$(readlink -- "${link_path}")"
    case "${link_target}" in
        /opt/deepin-wine10-stable/*)
            ln -sfn "/app/deepin-wine10-stable/${link_target#/opt/deepin-wine10-stable/}" \
                "${link_path}"
            ;;
        /app/deepin-wine10-stable/*)
            ;;
    esac
done < <(find "${prepare_prefix}" -type l -print0)

rm -f \
    "${prepare_prefix}/drive_c/windows/system32/winedbg.exe" \
    "${prepare_prefix}/drive_c/windows/syswow64/winedbg.exe"

printf '%s\n' "${package_version}" > "${prepare_prefix}/.deepin-wecom-package"
mv "${prepare_prefix}" "${WINEPREFIX}"
trap - EXIT
