#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/../flatpak/shared-wine.conf"
APP_DIR="$(realpath -- "${1:?用法：use-shared-wine-runtime.sh APPDIR [RUNTIME_FILES]}")"
RUNTIME_FILES="${2:-$(flatpak info --user --show-location "runtime/${SHARED_WINE_ID}//${SHARED_WINE_BRANCH}")/files}"
[[ -f "${APP_DIR}/metadata" && -d "${APP_DIR}/files" ]]
mkdir -p "${APP_DIR}/files/${SHARED_WINE_MOUNT}"

# 只改写构建目录中的已知底层路径，保持企业微信前缀内的绝对链接仍然有效。
while IFS= read -r relative_path; do
    [[ "${relative_path}" != /* && "${relative_path}" != *..* ]]
    rm -rf -- "${APP_DIR}/files/${relative_path}"
    mkdir -p "$(dirname -- "${APP_DIR}/files/${relative_path}")"
    ln -s "/app/${SHARED_WINE_MOUNT}/${relative_path}" \
        "${APP_DIR}/files/${relative_path}"
done < "${RUNTIME_FILES}/share/shared-wine/payload.list"
rm -rf -- "${APP_DIR}/files/share/wecom-deepin/adapter/dlls"
ln -s "/app/${SHARED_WINE_MOUNT}/adapter-dlls" \
    "${APP_DIR}/files/share/wecom-deepin/adapter/dlls"
python3 - "${APP_DIR}/metadata" "${SHARED_WINE_ID}" \
    "${SHARED_WINE_BRANCH}" "${SHARED_WINE_MOUNT}" <<'PY'
import configparser
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
metadata = configparser.ConfigParser(interpolation=None)
metadata.optionxform = str
metadata.read(path)
metadata[f"Extension {sys.argv[2]}"] = {
    "directory": sys.argv[4],
    "version": sys.argv[3],
    "autodelete": "false",
}
with path.open("w") as stream:
    metadata.write(stream, space_around_delimiters=False)
PY
