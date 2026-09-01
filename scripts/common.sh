#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="${WECOM_PROJECT_DIR:-$(cd -- "${SCRIPT_DIR}/.." && pwd -P)}"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"

# Keep the established runtime namespace so a future standalone package can
# adopt an existing POC prefix without copying gigabytes of user data.
STATE_DIR="${WECOM_STATE_DIR:-${XDG_STATE_HOME}/wecom-flatpak-poc}"
CACHE_DIR="${WECOM_CACHE_DIR:-${XDG_CACHE_HOME}/wecom-flatpak-poc}"
DATA_DIR="${WECOM_DATA_DIR:-${XDG_DATA_HOME}/wecom-flatpak-poc}"
LOG_DIR="${WECOM_LOG_DIR:-${STATE_DIR}/logs}"
SCALE_FACTOR_OVERRIDE="${WECOM_SCALE_FACTOR:-}"

NATIVE_RICHEDIT_DIR="${WECOM_NATIVE_RICHEDIT_DIR:-${DATA_DIR}/native-richedit}"
NATIVE_RICHEDIT_DLL_HOST="${NATIVE_RICHEDIT_DIR}/riched20.dll"
NATIVE_RICHEDIT_SHA256="c741226a0465a8c4edcbe0f3af54de02e21931122afe3a4dad8d49553fececcc"

FLATPAK_APP="org.winehq.Wine"
FLATPAK_BRANCH="stable-25.08"
FLATPAK_REF="${FLATPAK_APP}//${FLATPAK_BRANCH}"
FLATPAK_GECKO_REF="runtime/org.winehq.Wine.gecko/x86_64/${FLATPAK_BRANCH}"
FLATPAK_MONO_REF="runtime/org.winehq.Wine.mono/x86_64/${FLATPAK_BRANCH}"
FLATPAK_REMOTE="${WECOM_FLATPAK_REMOTE:-flathub-wecom}"
FLATPAK_REMOTE_URL="${WECOM_FLATPAK_REMOTE_URL:-https://mirrors.ustc.edu.cn/flathub}"
FLATPAK_GPG_KEY="${XDG_DATA_HOME}/flatpak/repo/flathub.trustedkeys.gpg"

PORTAL_FLATPAK_APP="io.github.loveyu.WeComWine"
PORTAL_FLATPAK_BRANCH="stable-25.08"
PORTAL_FLATPAK_REMOTE="wecom-wine-local"
PORTAL_FLATPAK_REPO="${WECOM_PORTAL_FLATPAK_REPO:-${DATA_DIR}/flatpak-repo}"
PORTAL_WINEPREFIX_HOST="${HOME}/.var/app/${PORTAL_FLATPAK_APP}/data/wine-wecom"
PORTAL_WINE_VERSION="11.0"
PORTAL_WINE_SHA256="c07a6857933c1fc60dff5448d79f39c92481c1e9db5aa628db9d0358446e0701"
PORTAL_WINE_URL="https://dl.winehq.org/wine/source/11.0/wine-11.0.tar.xz"
PORTAL_PATCHSET="mr10060-f36314a-wecom10"
RICHEDIT_EXTENSION_ID="io.github.loveyu.WeComWine.RichEdit"
RICHEDIT_EXTENSION_BRANCH="${PORTAL_FLATPAK_BRANCH}"
RICHEDIT_EXTENSION_REF="runtime/${RICHEDIT_EXTENSION_ID}/x86_64/${RICHEDIT_EXTENSION_BRANCH}"

ORIGINAL_WINEPREFIX_SANDBOX="/var/data/wine-wecom"
ORIGINAL_WINEPREFIX_HOST="${HOME}/.var/app/${FLATPAK_APP}/data/wine-wecom"
SHARED_WINEPREFIX_HOST="${DATA_DIR}/wine-prefix"
PORTAL_TEST_WINEPREFIX_HOST="${STATE_DIR}/portal-test-prefix"
RUNNER_STATE_FILE="${STATE_DIR}/runner.app"

ACTIVE_FLATPAK_APP="${FLATPAK_APP}"
ACTIVE_FLATPAK_BRANCH="${FLATPAK_BRANCH}"
if [[ -s "${RUNNER_STATE_FILE}" ]]; then
    configured_runner="$(<"${RUNNER_STATE_FILE}")"
    if [[ "${configured_runner}" == "${PORTAL_FLATPAK_APP}" ]]; then
        ACTIVE_FLATPAK_APP="${PORTAL_FLATPAK_APP}"
        ACTIVE_FLATPAK_BRANCH="${PORTAL_FLATPAK_BRANCH}"
    fi
fi

if [[ -f "${SHARED_WINEPREFIX_HOST}/system.reg" ]]; then
    WINEPREFIX_SANDBOX="${SHARED_WINEPREFIX_HOST}"
    WINEPREFIX_HOST="${SHARED_WINEPREFIX_HOST}"
elif [[ "${ACTIVE_FLATPAK_APP}" == "${PORTAL_FLATPAK_APP}" ]]; then
    WINEPREFIX_SANDBOX="${ORIGINAL_WINEPREFIX_SANDBOX}"
    WINEPREFIX_HOST="${PORTAL_WINEPREFIX_HOST}"
else
    WINEPREFIX_SANDBOX="${ORIGINAL_WINEPREFIX_SANDBOX}"
    WINEPREFIX_HOST="${ORIGINAL_WINEPREFIX_HOST}"
fi

WECOM_VERSION="5.0.10.6015"
WECOM_INSTALLER="WeCom_${WECOM_VERSION}.exe"
WECOM_URL="https://dldir1.qq.com/wework/work_weixin/${WECOM_INSTALLER}"
WECOM_SHA256="d46b1cc2603c70ff9cccd85998eed0c0d61f11a3a68e050b0695111294c10c87"
WECOM_INSTALLER_HOST="${CACHE_DIR}/${WECOM_INSTALLER}"

mkdir -p "${STATE_DIR}" "${CACHE_DIR}" "${LOG_DIR}"

rotate_log() {
    local log_file="$1"
    local max_bytes="${2:-52428800}"

    if [[ -f "${log_file}" ]] && (( $(stat -c '%s' "${log_file}") > max_bytes )); then
        mv -f "${log_file}.1" "${log_file}.2" 2>/dev/null || true
        mv -f "${log_file}" "${log_file}.1"
    fi
}

write_status() {
    local status_file="$1"
    local stage="$2"
    local detail="${3:-}"

    {
        printf 'updated_at=%s\n' "$(date --iso-8601=seconds)"
        printf 'stage=%s\n' "${stage}"
        printf 'detail=%s\n' "${detail}"
    } > "${status_file}"
}

load_desktop_environment() {
    local variable value

    for variable in DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS; do
        [[ -n "${!variable:-}" ]] && continue
        value="$(systemctl --user show-environment 2>/dev/null | \
            sed -n "s/^${variable}=//p" | head -n 1 || true)"
        [[ -n "${value}" ]] && export "${variable}=${value}"
    done
}

normalize_scale_factor() {
    local value="$1"

    [[ "${value}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
    LC_ALL=C awk -v value="${value}" '
        BEGIN {
            if (value < 0.5 || value > 4) exit 1
            printf "%.4f", value
        }
    ' | sed -e 's/0*$//' -e 's/\.$//'
}

detect_system_scale_factor() {
    local dpi=''
    local scale=''

    if [[ -n "${SCALE_FACTOR_OVERRIDE}" ]]; then
        if ! scale="$(normalize_scale_factor "${SCALE_FACTOR_OVERRIDE}")"; then
            printf '无效的企业微信缩放倍率：%s（允许范围 0.5-4）\n' \
                "${SCALE_FACTOR_OVERRIDE}" >&2
            return 64
        fi
        printf '%s\n' "${scale}"
        return
    fi

    load_desktop_environment
    if command -v xrdb >/dev/null 2>&1; then
        dpi="$(xrdb -query 2>/dev/null | awk -F: '
            tolower($1) ~ /^[[:space:]]*xft[.]dpi[[:space:]]*$/ {
                gsub(/[[:space:]]/, "", $2); print $2; exit
            }
        ' || true)"
    fi
    if [[ "${dpi}" =~ ^[0-9]+([.][0-9]+)?$ ]] && \
       scale="$(normalize_scale_factor "$(LC_ALL=C awk -v dpi="${dpi}" \
           'BEGIN { printf "%.6f", dpi / 96 }')")"; then
        printf '%s\n' "${scale}"
        return
    fi

    if command -v kscreen-doctor >/dev/null 2>&1; then
        scale="$(kscreen-doctor -o 2>/dev/null | \
            sed $'s/\033\\[[0-9;]*[[:alpha:]]//g' | \
            sed -n 's/^[[:space:]]*Scale:[[:space:]]*//p' | head -n 1 || true)"
    fi
    if [[ -n "${scale}" ]] && scale="$(normalize_scale_factor "${scale}")"; then
        printf '%s\n' "${scale}"
        return
    fi

    printf '1\n'
}

scale_factor_to_wine_dpi() {
    LC_ALL=C awk -v scale="$1" 'BEGIN { printf "%d\n", int(scale * 96 + 0.5) }'
}

flatpak_wine() {
    local command_name="$1"
    local wine_debug="${WINEDEBUG_VALUE:--all}"
    local -a instance_options=()
    local -a prefix_mount=()
    local -a test_environment=()
    shift

    load_desktop_environment

    if [[ "${WINEPREFIX_HOST}" == "${SHARED_WINEPREFIX_HOST}" ||
          "${WINEPREFIX_HOST}" == "${PORTAL_TEST_WINEPREFIX_HOST}" ]]; then
        prefix_mount+=(--filesystem="${WINEPREFIX_HOST}")
    fi
    if [[ -n "${PORTAL_SMOKE_TIMEOUT_MS:-}" ]]; then
        test_environment+=(--env="PORTAL_SMOKE_TIMEOUT_MS=${PORTAL_SMOKE_TIMEOUT_MS}")
    fi
    if [[ -n "${WINE_FORCE_PORTAL:-}" ]]; then
        test_environment+=(--env="WINE_FORCE_PORTAL=${WINE_FORCE_PORTAL}")
    fi
    if [[ -n "${FLATPAK_INSTANCE_ID_FD:-}" ]]; then
        if [[ ! "${FLATPAK_INSTANCE_ID_FD}" =~ ^[0-9]+$ ]]; then
            printf '无效的 Flatpak instance-id 文件描述符：%s\n' \
                "${FLATPAK_INSTANCE_ID_FD}" >&2
            return 64
        fi
        instance_options+=(--instance-id-fd="${FLATPAK_INSTANCE_ID_FD}")
    fi

    flatpak run \
        --user \
        --branch="${ACTIVE_FLATPAK_BRANCH}" \
        --arch=x86_64 \
        "${instance_options[@]}" \
        --nosocket=wayland \
        --filesystem="${CACHE_DIR}:ro" \
        "${prefix_mount[@]}" \
        --env="WINEPREFIX=${WINEPREFIX_SANDBOX}" \
        --env="LANG=zh_CN.UTF-8" \
        --env="LC_ALL=zh_CN.UTF-8" \
        --env="XMODIFIERS=@im=fcitx" \
        --env="GTK_IM_MODULE=fcitx" \
        --env="QT_IM_MODULE=fcitx" \
        --env="WINEDEBUG=${wine_debug}" \
        "${test_environment[@]}" \
        --command="${command_name}" \
        "${ACTIVE_FLATPAK_APP}" "$@"
}

flatpak_wine_scaled() {
    local wine_dpi="$1"
    shift

    # Keep the registry update and WeCom in one Flatpak/wineserver lifetime.
    # Separate Flatpak invocations can race while saving the shared prefix.
    flatpak_wine sh -c '
        wine reg.exe add "HKCU\Control Panel\Desktop" \
            /v LogPixels /t REG_DWORD /d "$1" /f >/dev/null
        shift
        exec "$@"
    ' sh "${wine_dpi}" "$@"
}
