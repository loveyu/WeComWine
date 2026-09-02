#!/usr/bin/env bash

set -Eeuo pipefail

readonly RULE_ID="wecom-wine-system-frame"
readonly KWIN_RULES_FILE="kwinrulesrc"
readonly XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
readonly XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
readonly KWIN_RULES_PATH="${XDG_CONFIG_HOME}/${KWIN_RULES_FILE}"
readonly BACKUP_DIR="${XDG_STATE_HOME}/wecom-flatpak-poc/backups"
readonly BACKUP_FILE="${BACKUP_DIR}/kwinrulesrc.before-stale-system-frame-removal"

read_rule_list() {
    kreadconfig6 --file "${KWIN_RULES_FILE}" \
        --group General --key rules 2>/dev/null || true
}

rule_list_count() {
    local rule_list="$1"

    tr ',' '\n' <<< "${rule_list}" | awk 'NF { count++ } END { print count + 0 }'
}

reconfigure_kwin() {
    local qdbus_command=''
    local variable=''
    local value=''

    for variable in DISPLAY DBUS_SESSION_BUS_ADDRESS; do
        [[ -n "${!variable:-}" ]] && continue
        value="$(systemctl --user show-environment 2>/dev/null | \
            sed -n "s/^${variable}=//p" | head -n 1 || true)"
        [[ -n "${value}" ]] && export "${variable}=${value}"
    done

    for qdbus_command in qdbus6 qdbus; do
        command -v "${qdbus_command}" >/dev/null 2>&1 || continue
        timeout 5s "${qdbus_command}" org.kde.KWin /KWin reconfigure \
            >/dev/null 2>&1 || true
        return
    done
}

if [[ ! -f "${KWIN_RULES_PATH}" ]]; then
    printf '未发现历史 KWin 企业微信系统边框规则。\n'
    exit 0
fi

if ! command -v kwriteconfig6 >/dev/null 2>&1 || \
   ! command -v kreadconfig6 >/dev/null 2>&1; then
    printf '无法清理历史 KWin 企业微信系统边框规则：缺少 KDE KConfig 命令。\n' >&2
    exit 69
fi

rule_list="$(read_rule_list)"
if ! grep -Fxq "[${RULE_ID}]" "${KWIN_RULES_PATH}" && \
   ! tr ',' '\n' <<< "${rule_list}" | grep -Fxq "${RULE_ID}"; then
    printf '未发现历史 KWin 企业微信系统边框规则。\n'
    exit 0
fi

install -d "${BACKUP_DIR}"
if [[ ! -e "${BACKUP_FILE}" ]]; then
    cp -a "${KWIN_RULES_PATH}" "${BACKUP_FILE}"
fi

filtered_list="$(tr ',' '\n' <<< "${rule_list}" | \
    awk -v rule_id="${RULE_ID}" 'NF && $0 != rule_id' | \
    paste -sd, - || true)"
if [[ -n "${filtered_list}" ]]; then
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group General --key rules "${filtered_list}"
else
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group General --key rules --delete ''
fi
kwriteconfig6 --file "${KWIN_RULES_FILE}" \
    --group General --key count "$(rule_list_count "${filtered_list}")"

for key in Description Enabled wmclass wmclassmatch wmclasscomplete \
    title titlematch noborder noborderrule; do
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key "${key}" --delete ''
done

reconfigure_kwin
printf '已清理历史 KWin 企业微信系统边框规则：%s\n' "${RULE_ID}"
printf '清理前配置备份：%s\n' "${BACKUP_FILE}"
