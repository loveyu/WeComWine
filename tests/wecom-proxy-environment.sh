#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
PROXY_ENVIRONMENT="${PROJECT_DIR}/scripts/wecom-proxy-environment.sh"

proxy_variables='http_proxy https_proxy ftp_proxy all_proxy no_proxy socks_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY SOCKS_PROXY'

env \
    http_proxy=http://lower-http \
    https_proxy=http://lower-https \
    ftp_proxy=http://lower-ftp \
    all_proxy=socks5://lower-all \
    no_proxy=lower-no-proxy \
    socks_proxy=socks5://lower-socks \
    HTTP_PROXY=http://upper-http \
    HTTPS_PROXY=http://upper-https \
    FTP_PROXY=http://upper-ftp \
    ALL_PROXY=socks5://upper-all \
    NO_PROXY=upper-no-proxy \
    SOCKS_PROXY=socks5://upper-socks \
    bash -c '
        source "$1"
        for variable in $2; do
            if [[ -n "${!variable+x}" ]]; then
                printf "默认启动仍保留了代理变量：%s\n" "${variable}" >&2
                exit 1
            fi
        done
    ' sh "${PROXY_ENVIRONMENT}" "${proxy_variables}"

env \
    FORCE_ENABLE_PROXY_WECOM=1 \
    HTTP_PROXY=http://upper-http \
    no_proxy=localhost \
    bash -c '
        source "$1"
        [[ "${HTTP_PROXY}" == http://upper-http ]]
        [[ "${no_proxy}" == localhost ]]
    ' sh "${PROXY_ENVIRONMENT}"

env \
    FORCE_ENABLE_PROXY_WECOM=0 \
    HTTPS_PROXY=http://must-be-cleared \
    bash -c '
        source "$1"
        [[ -z "${HTTPS_PROXY+x}" ]]
    ' sh "${PROXY_ENVIRONMENT}"
