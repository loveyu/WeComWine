#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
source "${PROJECT_DIR}/flatpak/shared-wine.conf"

SOURCE_REF="io.github.loveyu.WeComWine.Deepin//stable-25.08"
SOURCE_FILES="${SHARED_WINE_SOURCE_FILES:-$(flatpak info --user --show-location "${SOURCE_REF}")/files}"
CACHE_ROOT="${SHARED_WINE_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/shared-wine-flatpak}"
LOCAL_REPO="${SHARED_WINE_REPO:-${XDG_DATA_HOME:-${HOME}/.local/share}/shared-wine-flatpak/repo}"
REMOTE_NAME="shared-wine-local"
RUNTIME_REF="${SHARED_WINE_ID}//${SHARED_WINE_BRANCH}"

mkdir -p "${CACHE_ROOT}" "${LOCAL_REPO}"
exec 9> "${CACHE_ROOT}/build.lock"
flock -n 9 || exit 75
if [[ -L "${SOURCE_FILES}/deepin-wine10-stable" ]]; then
    # 应用层已瘦身时，从已安装基础包重建，仍可更新字体等公共资源。
    SOURCE_REF="runtime/${RUNTIME_REF}"
    SOURCE_FILES="$(flatpak info --user --show-location "${SOURCE_REF}")/files"
fi
adapter_path=share/wecom-deepin/adapter/dlls
[[ ! -d "${SOURCE_FILES}/adapter-dlls" ]] || adapter_path=adapter-dlls
for required_path in deepin-wine10-stable/bin/wine \
    deepin-wine10-stable/bin/wineserver \
    "${adapter_path}/x86_64-windows/user32.dll"; do
    [[ -f "${SOURCE_FILES}/${required_path}" ]] || {
        printf '共享 Wine 源文件缺失：%s\n' "${required_path}" >&2
        exit 65
    }
done

portal_cache="${WECOM_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/wecom-flatpak-poc}"
portal_build="${WECOM_DEEPIN_WINE10_PORTAL_BUILD:-${portal_cache}/deepin-wine10-portal/10.14-mr10060-wine10-wecom1}"
WECOM_DEEPIN_WINE10_PORTAL_BUILD="${portal_build}" \
    "${SCRIPT_DIR}/build-deepin-wine10-portal.sh"

APP_DIR="$(mktemp -d "${CACHE_ROOT}/runtime.XXXXXX")"
FILES="${APP_DIR}/files"
mkdir -p "${FILES}/share/shared-wine"
PAYLOAD_LIST="${FILES}/share/shared-wine/payload.list"
# 保留旧 Wine 11 helper 路径以兼容企业微信既有入口；主应用统一使用 Deepin 10。
# 不复制企业微信安装模板、客户端、字体、登录态或运行脚本。
{
    printf '%s\n' deepin-wine10-stable i386 lib32 share/wine share/doc/deepin-wine10-stable
    find "${SOURCE_FILES}/lib" -mindepth 1 -maxdepth 1 \
        ! -name i386-linux-gnu ! -name debug -printf 'lib/%f\n'
    find "${SOURCE_FILES}/bin" -mindepth 1 -maxdepth 1 \
        ! -name deepin-wine ! -name wecom-deepin ! -name wecom-host-open \
        ! -name wecom-proxy-environment.sh -printf 'bin/%f\n'
} | LC_ALL=C sort > "${PAYLOAD_LIST}"
while IFS= read -r relative_path; do
    mkdir -p "$(dirname -- "${FILES}/${relative_path}")"
    cp -a --reflink=auto "${SOURCE_FILES}/${relative_path}" "${FILES}/${relative_path}"
done < "${PAYLOAD_LIST}"
cp -a --reflink=auto "${SOURCE_FILES}/${adapter_path}" \
    "${FILES}/adapter-dlls"
# SHBrowseForFolder 的 Portal 代码位于 shell32，不能只打包 comdlg32。
for arch in x86_64 i386; do
    build_arch=build64
    [[ "${arch}" != i386 ]] || build_arch=build32
    install -m 0644 "${portal_build}/${build_arch}/dlls/shell32/${arch}-windows/shell32.dll" \
        "${FILES}/deepin-wine10-stable/lib/wine/${arch}-windows/shell32.dll"
    for directory in deepin-wine10-stable/lib/wine adapter-dlls; do
        install -m 0644 "${portal_build}/${build_arch}/dlls/comdlg32/${arch}-windows/comdlg32.dll" \
            "${FILES}/${directory}/${arch}-windows/comdlg32.dll"
    done
done
install -m 0755 "${portal_build}/build64/dlls/comdlg32/comdlg32.so" \
    "${FILES}/deepin-wine10-stable/lib/wine/x86_64-unix/comdlg32.so"
"${SCRIPT_DIR}/bundle-shared-wine-fonts.sh" "${FILES}"
if [[ -n "${SHARED_WINE_SOURCE_FILES:-}" ]]; then
    source_commit="${SHARED_WINE_SOURCE_SIGNATURE:-assembled-build}"
    SOURCE_REF="wecom-assembled-build"
else
    source_commit="$(flatpak info --user --show-commit "${SOURCE_REF}")"
fi
{
    printf 'source_ref=%s\nsource_commit=%s\n' "${SOURCE_REF}" "${source_commit}"
    (cd "${FILES}" && find deepin-wine10-stable adapter-dlls \
        -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum)
} > "${FILES}/share/shared-wine/source.txt"
cat > "${APP_DIR}/metadata" <<EOF
[Runtime]
name=${SHARED_WINE_ID}

[ExtensionOf]
ref=runtime/org.freedesktop.Platform/x86_64/25.08
runtime=org.freedesktop.Platform/x86_64/25.08
EOF
flatpak build-export --runtime --files=files --disable-fsync \
    --subject="Shared Deepin Wine ${SHARED_WINE_BRANCH}" \
    "${LOCAL_REPO}" "${APP_DIR}" "${SHARED_WINE_BRANCH}"
flatpak remote-add --user --if-not-exists --no-gpg-verify \
    "${REMOTE_NAME}" "file://${LOCAL_REPO}"
flatpak remote-modify --user --url="file://${LOCAL_REPO}" "${REMOTE_NAME}"
if [[ "${SHARED_WINE_SKIP_INSTALL:-0}" != 1 ]]; then
    flatpak install --user --noninteractive -y --reinstall --no-deps --no-related \
        "${REMOTE_NAME}" "runtime/${RUNTIME_REF}"
fi
printf '%s\n' "${APP_DIR}" > "${CACHE_ROOT}/latest-build"
printf '已构建共享 Wine 基础包：%s\n' "${RUNTIME_REF}"
