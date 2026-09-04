#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
INITIALIZER="${PROJECT_DIR}/scripts/initialize-deepin-prefix.sh"
LAUNCHER="${PROJECT_DIR}/scripts/run-deepin-package.sh"
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

assert_initializer_reaches_archive_check() {
    local prefix="$1"
    local output="$2"
    local exit_code=0

    if WINEPREFIX="${prefix}" bash "${INITIALIZER}" >"${output}" 2>&1; then
        printf '初始化器在缺少官方代码包时不应成功。\n' >&2
        exit 1
    else
        exit_code="$?"
    fi

    [[ "${exit_code}" == 65 ]]
    grep -Fq 'Flatpak 中缺少 Deepin 官方企业微信代码包' "${output}"
    [[ ! -e "${prefix}" ]]
}

fresh_prefix="${TEST_ROOT}/fresh-prefix"
launcher_output="${TEST_ROOT}/launcher.log"
if WINEPREFIX="${fresh_prefix}" bash "${LAUNCHER}" >"${launcher_output}" 2>&1; then
    printf '本地缺少 /app payload 时启动器不应成功。\n' >&2
    exit 1
fi
[[ ! -e "${fresh_prefix}" ]]
[[ -f "${fresh_prefix}.launch.lock" ]]

empty_prefix="${TEST_ROOT}/empty-prefix"
mkdir "${empty_prefix}"
assert_initializer_reaches_archive_check \
    "${empty_prefix}" "${TEST_ROOT}/empty-prefix.log"

legacy_prefix="${TEST_ROOT}/legacy-prefix"
mkdir "${legacy_prefix}"
: > "${legacy_prefix}/.wecom-launch.lock"
assert_initializer_reaches_archive_check \
    "${legacy_prefix}" "${TEST_ROOT}/legacy-prefix.log"

unknown_prefix="${TEST_ROOT}/unknown-prefix"
mkdir "${unknown_prefix}"
: > "${unknown_prefix}/system.reg"
unknown_output="${TEST_ROOT}/unknown-prefix.log"
unknown_exit=0
if WINEPREFIX="${unknown_prefix}" bash "${INITIALIZER}" >"${unknown_output}" 2>&1; then
    printf '含未知内容的前缀不应被初始化器覆盖。\n' >&2
    exit 1
else
    unknown_exit="$?"
fi
[[ "${unknown_exit}" == 73 ]]
grep -Fq '为避免混用其他安装包，拒绝覆盖。' "${unknown_output}"
[[ -f "${unknown_prefix}/system.reg" ]]
