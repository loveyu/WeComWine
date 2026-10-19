#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "${TEST_ROOT}"' EXIT
APP_DIR="${TEST_ROOT}/app"
BASE_DIR="${TEST_ROOT}/runtime"
mkdir -p "${APP_DIR}/files/deepin-wine10-stable" \
    "${APP_DIR}/files/share/wecom-deepin/adapter/dlls" \
    "${BASE_DIR}/share/shared-wine"
printf '%s\n' deepin-wine10-stable > "${BASE_DIR}/share/shared-wine/payload.list"
printf '%s\n' private-client > "${APP_DIR}/files/share/wecom-deepin/adapter/client.7z"
cat > "${APP_DIR}/metadata" <<'EOF'
[Application]
name=io.github.loveyu.WeComWine.Deepin
runtime=org.freedesktop.Platform/x86_64/25.08
sdk=org.freedesktop.Sdk/x86_64/25.08

[Context]
filesystems=home;
EOF
"${PROJECT_DIR}/scripts/use-shared-wine-runtime.sh" "${APP_DIR}" "${BASE_DIR}"
[[ "$(readlink "${APP_DIR}/files/deepin-wine10-stable")" == /app/shared-wine/deepin-wine10-stable ]]
[[ "$(readlink "${APP_DIR}/files/share/wecom-deepin/adapter/dlls")" == /app/shared-wine/adapter-dlls ]]
[[ "$(cat "${APP_DIR}/files/share/wecom-deepin/adapter/client.7z")" == private-client ]]
python3 - "${APP_DIR}/metadata" <<'PY'
import configparser
import sys

metadata = configparser.ConfigParser()
metadata.read(sys.argv[1])
assert metadata["Application"]["runtime"] == "org.freedesktop.Platform/x86_64/25.08"
assert metadata["Context"]["filesystems"] == "home;"
extension = metadata["Extension io.github.loveyu.Wine.Deepin"]
assert extension["directory"] == "shared-wine"
assert extension["version"] == "10.14deepin11-25.08"
assert extension["autodelete"] == "false"
PY
