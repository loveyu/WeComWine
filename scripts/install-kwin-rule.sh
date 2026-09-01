#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

readonly RULE_ID="wecom-wine-system-frame"
readonly RULE_DESCRIPTION="企业微信强制系统边框"
readonly KWIN_RULES_FILE="kwinrulesrc"
readonly KWIN_RULES_PATH="${XDG_CONFIG_HOME:-${HOME}/.config}/${KWIN_RULES_FILE}"
readonly BACKUP_DIR="${STATE_DIR}/backups"
readonly BACKUP_FILE="${BACKUP_DIR}/kwinrulesrc.before-system-frame"

read_rule_list() {
    kreadconfig6 --file "${KWIN_RULES_FILE}" \
        --group General --key rules 2>/dev/null || true
}

rule_list_contains() {
    local rule_list="$1"
    local candidate=''

    while IFS= read -r candidate; do
        [[ "${candidate}" == "${RULE_ID}" ]] && return 0
    done < <(tr ',' '\n' <<< "${rule_list}")
    return 1
}

rule_list_count() {
    local rule_list="$1"

    tr ',' '\n' <<< "${rule_list}" | awk 'NF { count++ } END { print count + 0 }'
}

write_rule_list() {
    local rule_list="$1"

    if [[ -n "${rule_list}" ]]; then
        kwriteconfig6 --file "${KWIN_RULES_FILE}" \
            --group General --key rules "${rule_list}"
    else
        kwriteconfig6 --file "${KWIN_RULES_FILE}" \
            --group General --key rules --delete ''
    fi
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group General --key count "$(rule_list_count "${rule_list}")"
}

reconfigure_kwin() {
    local qdbus_command=''

    load_desktop_environment
    for qdbus_command in qdbus6 qdbus; do
        command -v "${qdbus_command}" >/dev/null 2>&1 || continue
        "${qdbus_command}" org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
        return
    done
}

install_rule() {
    local rule_list=''

    install -d "$(dirname -- "${KWIN_RULES_PATH}")" "${BACKUP_DIR}"
    if [[ -f "${KWIN_RULES_PATH}" && ! -e "${BACKUP_FILE}" ]]; then
        cp -a "${KWIN_RULES_PATH}" "${BACKUP_FILE}"
    fi

    rule_list="$(read_rule_list)"
    if ! rule_list_contains "${rule_list}"; then
        if [[ -n "${rule_list}" ]]; then
            rule_list="${rule_list},${RULE_ID}"
        else
            rule_list="${RULE_ID}"
        fi
    fi
    write_rule_list "${rule_list}"

    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key Description "${RULE_DESCRIPTION}"
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key Enabled --type bool true
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key wmclass wxwork.exe
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key wmclassmatch 1
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key wmclasscomplete --type bool false
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key title 企业微信
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key titlematch 1
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key noborder --type bool false
    # KWin Rules::Force is value 2. Force prevents the client from restoring
    # its _MOTIF_WM_HINTS no-border preference after the first move.
    kwriteconfig6 --file "${KWIN_RULES_FILE}" \
        --group "${RULE_ID}" --key noborderrule 2

    reconfigure_kwin
    printf '已安装 KWin 企业微信系统边框规则：%s\n' "${RULE_ID}"
}

remove_rule() {
    local rule_list=''
    local filtered_list=''
    local key=''

    rule_list="$(read_rule_list)"
    filtered_list="$(tr ',' '\n' <<< "${rule_list}" | \
        awk -v rule_id="${RULE_ID}" 'NF && $0 != rule_id' | \
        paste -sd, - || true)"
    write_rule_list "${filtered_list}"

    for key in Description Enabled wmclass wmclassmatch wmclasscomplete \
        title titlematch noborder noborderrule; do
        kwriteconfig6 --file "${KWIN_RULES_FILE}" \
            --group "${RULE_ID}" --key "${key}" --delete ''
    done

    reconfigure_kwin
    printf '已移除 KWin 企业微信系统边框规则：%s\n' "${RULE_ID}"
}

if ! command -v kwriteconfig6 >/dev/null 2>&1 || \
   ! command -v kreadconfig6 >/dev/null 2>&1; then
    printf '跳过 KWin 系统边框规则：缺少 KDE KConfig 命令\n'
    exit 0
fi

case "${1:-install}" in
    install)
        install_rule
        ;;
    remove)
        remove_rule
        ;;
    *)
        printf '用法：%s [install|remove]\n' "$0" >&2
        exit 64
        ;;
esac
