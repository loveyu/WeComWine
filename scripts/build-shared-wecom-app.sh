#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
source "${PROJECT_DIR}/flatpak/shared-wine.conf"
APP_ID="io.github.loveyu.WeComWine.Deepin"
APP_BRANCH="stable-25.08"
SOURCE_DIR="$(flatpak info --user --show-location "${APP_ID}//${APP_BRANCH}")"
CACHE_ROOT="${SHARED_WINE_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/shared-wine-flatpak}"
LOCAL_REPO="${WECOM_SHARED_APP_REPO:-${XDG_DATA_HOME:-${HOME}/.local/share}/wecom-flatpak-poc/deepin-flatpak-repo}"

"${SCRIPT_DIR}/build-shared-wine-runtime.sh"
exec 9> "${CACHE_ROOT}/wecom-app.lock"
flock -n 9 || exit 75
APP_DIR="$(mktemp -d "${CACHE_ROOT}/wecom-app.XXXXXX")"
cp -a --reflink=auto "${SOURCE_DIR}/files" "${APP_DIR}/files"
cp -a "${SOURCE_DIR}/metadata" "${APP_DIR}/metadata"
# 已安装部署可能仍带旧菜单词，重建应用层时使用当前源码中的启动文件。
install -m 0644 "${PROJECT_DIR}/desktop/${APP_ID}.desktop" \
    "${APP_DIR}/files/share/applications/${APP_ID}.desktop"
"${SCRIPT_DIR}/use-shared-wine-runtime.sh" "${APP_DIR}"
flatpak build-finish "${APP_DIR}"
flatpak build-export --disable-fsync --update-appstream \
    --subject="WeCom application layer with shared Deepin Wine ${SHARED_WINE_BRANCH}" \
    "${LOCAL_REPO}" "${APP_DIR}" "${APP_BRANCH}"
flatpak remote-add --user --if-not-exists --no-gpg-verify \
    wecom-deepin-local "file://${LOCAL_REPO}"
flatpak remote-modify --user --url="file://${LOCAL_REPO}" wecom-deepin-local
flatpak install --user --noninteractive -y --reinstall --no-deps --no-related \
    wecom-deepin-local "${APP_ID}//${APP_BRANCH}"
printf '已安装企业微信应用层；正在运行的实例会在下次启动使用共享基础包。\n'
