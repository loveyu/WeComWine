#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
source "${PROJECT_DIR}/flatpak/shared-wine.conf"
LAN_ROOT="${WECOM_LAN_ROOT:-${XDG_DATA_HOME:-${HOME}/.local/share}/flatpak-lan}"
INSTALL_REPO="${XDG_DATA_HOME:-${HOME}/.local/share}/flatpak/repo"
REPO="${LAN_ROOT}/repo"
PROJECTS=(wecom-wine-flatpak wechat-devtools-wine-flatpak alipay-devtools-wine-flatpak)
REFS=(
    "runtime/${SHARED_WINE_ID}/x86_64/${SHARED_WINE_BRANCH}"
    app/io.github.loveyu.WeComWine.Deepin/x86_64/stable-25.08
    app/io.github.loveyu.WeChatDevToolsWine/x86_64/stable-25.08
    app/io.github.loveyu.AlipayDevToolsWine/x86_64/stable-25.08
)

mkdir -p "${LAN_ROOT}/integration"
exec 9> "${LAN_ROOT}/publish.lock"
flock -n 9 || exit 75
TEMP_DIR="$(mktemp -d "${LAN_ROOT}/.publish.XXXXXX")"
trap 'rm -rf -- "${TEMP_DIR}"' EXIT

# 发布已安装且已验证的部署，不读取 Wine 前缀、工作区、账号或运行日志。
for project in "${PROJECTS[@]}"; do
    project_dir="${PROJECT_DIR}/../${project}"
    if [[ -n "$(git -C "${project_dir}" status --porcelain)" ]]; then
        printf '请先提交源码再发布：%s\n' "${project}" >&2
        exit 65
    fi
done
commits=()
for ref in "${REFS[@]}"; do
    commits+=("$(flatpak info --user --show-commit "${ref}")")
    flatpak info --user --show-metadata "${ref}" > "${TEMP_DIR}/metadata"
    if [[ "${ref}" == app/* ]]; then
        python3 - "${TEMP_DIR}/metadata" "${SHARED_WINE_ID}" "${SHARED_WINE_BRANCH}" <<'PY'
import configparser
import sys

metadata = configparser.ConfigParser(interpolation=None)
metadata.read(sys.argv[1])
extension = metadata[f"Extension {sys.argv[2]}"]
assert extension["directory"] == "shared-wine"
assert extension["version"] == sys.argv[3]
PY
    fi
done
runtime_files="$(flatpak info --user --show-location "${REFS[0]}")/files"
(cd "${runtime_files}" && sha256sum --quiet --check share/shared-wine/fonts.sha256)

# 先写入基础包和应用提交，最后统一更新 summary；保留旧提交和增量回滚历史。
for index in "${!REFS[@]}"; do
    flatpak build-commit-from --disable-fsync --no-update-summary \
        --src-repo="${INSTALL_REPO}" --src-ref="${commits[index]}" \
        --subject="Private shared Wine release: ${REFS[index]}" \
        "${REPO}" "${REFS[index]}"
done
flatpak build-update-repo --generate-static-deltas --static-delta-jobs=2 "${REPO}"

# 两个开发者工具仍使用宿主启动脚本；随包提供固定提交的无用户数据源码集成。
for project in "${PROJECTS[@]}"; do
    project_dir="${PROJECT_DIR}/../${project}"
    git -C "${project_dir}" archive --format=tar --prefix="${project}/" HEAD | \
        gzip -n > "${TEMP_DIR}/${project}.tar.gz"
    printf '%s\t%s\n' "${project}" "$(git -C "${project_dir}" rev-parse HEAD)" \
        >> "${TEMP_DIR}/sources.tsv"
done
for ref in "${REFS[@]}"; do
    printf '%s\t%s\n' "${ref}" "$(<"${REPO}/refs/heads/${ref}")" \
        >> "${TEMP_DIR}/refs.tsv"
done
(cd "${TEMP_DIR}" && sha256sum ./*.tar.gz > SHA256SUMS)
install -m 0644 "${TEMP_DIR}"/*.tar.gz "${TEMP_DIR}/sources.tsv" \
    "${TEMP_DIR}/refs.tsv" "${TEMP_DIR}/SHA256SUMS" "${LAN_ROOT}/integration/"
printf '已发布共享底层、三个应用层和宿主启动集成：%s\n' "${LAN_ROOT}"
