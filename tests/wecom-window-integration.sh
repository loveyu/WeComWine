#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
fixture_root="$(mktemp -d)"
mock_bin="${fixture_root}/bin"
call_log="${fixture_root}/calls.log"

cleanup() {
    rm -rf -- "${fixture_root}"
}
trap cleanup EXIT

mkdir -p "${mock_bin}"
cat > "${mock_bin}/mock-command" <<'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

command_name="$(basename "$0")"
case "${command_name}" in
    xwininfo)
        if [[ "${1:-}" == "-root" ]]; then
            printf '%s\n' \
                '     0x2000002 (has no name): ("wxwork.exe" "wxwork.exe")  1921x42+0+0  +0+0'
        elif [[ "${2:-}" == "0x2000002" ]]; then
            cat <<'DETAILS'
  Absolute upper-left X:  0
  Absolute upper-left Y:  0
  Width: 1921
  Height: 42
  Depth: 32
  Map State: IsViewable
  Override Redirect State: yes
DETAILS
        elif [[ "${2:-}" == "0x2000001" ]]; then
            cat <<'DETAILS'
  Absolute upper-left X:  0
  Absolute upper-left Y:  0
  Width: 1920
  Height: 1080
  Depth: 24
  Map State: IsViewable
  Override Redirect State: no
DETAILS
        else
            exit 1
        fi
        ;;
    xprop)
        if [[ "${1:-}" == "-root" ]]; then
            printf '_NET_ACTIVE_WINDOW(WINDOW): window id # 0x2000001\n'
        elif [[ "${2:-}" == "0x2000002" ]]; then
            cat <<'PROPERTIES'
WM_CLASS(STRING) = "wxwork.exe", "wxwork.exe"
_NET_WM_NAME(UTF8_STRING) =
WM_HINTS(WM_HINTS):
        Client accepts input or input focus: False
_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_DIALOG
_NET_WM_STATE:  not found.
WM_TRANSIENT_FOR(WINDOW): window id # 0x2000001
PROPERTIES
        elif [[ "${2:-}" == "0x2000001" ]]; then
            printf '%s\n' \
                'WM_CLASS(STRING) = "wxwork.exe", "wxwork.exe"' \
                '_NET_WM_NAME(UTF8_STRING) = "企业微信"' \
                '_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_NORMAL'
            if [[ "${MOCK_FULLSCREEN:-1}" == "1" ]]; then
                printf '%s\n' '_NET_WM_STATE(ATOM) = _NET_WM_STATE_MAXIMIZED_VERT, _NET_WM_STATE_MAXIMIZED_HORZ, _NET_WM_STATE_FULLSCREEN'
            else
                printf '%s\n' '_NET_WM_STATE(ATOM) = _NET_WM_STATE_MAXIMIZED_VERT, _NET_WM_STATE_MAXIMIZED_HORZ'
            fi
            printf '%s\n' 'WM_TRANSIENT_FOR:  not found.'
        else
            exit 1
        fi
        ;;
    wmctrl|xdotool)
        printf '%s %s\n' "${command_name}" "$*" >> "${MOCK_CALL_LOG}"
        ;;
    *)
        exit 127
        ;;
esac
EOF
chmod +x "${mock_bin}/mock-command"
for command_name in wmctrl xdotool xprop xwininfo; do
    ln -s mock-command "${mock_bin}/${command_name}"
done

MOCK_CALL_LOG="${call_log}" \
PATH="${mock_bin}:${PATH}" \
    bash "${SOURCE_ROOT}/scripts/manage-wecom-titlebar-overlay.sh" --once \
    > "${fixture_root}/fullscreen.log"

grep -Fxq -- 'wmctrl -ir 0x2000001 -b remove,fullscreen' "${call_log}"
grep -Fq 'restored work-area owner=0x2000001 removed-state=fullscreen' \
    "${fixture_root}/fullscreen.log"
if grep -Fq 'xdotool ' "${call_log}"; then
    printf '活动主窗口不应触发顶栏映射变更。\n' >&2
    exit 1
fi

printf '' > "${call_log}"
MOCK_CALL_LOG="${call_log}" \
MOCK_FULLSCREEN=0 \
PATH="${mock_bin}:${PATH}" \
    bash "${SOURCE_ROOT}/scripts/manage-wecom-titlebar-overlay.sh" --once \
    > "${fixture_root}/maximized.log"

if [[ -s "${call_log}" ]]; then
    printf '未进入全屏的最大化窗口不应触发窗口状态变更。\n' >&2
    exit 1
fi

printf '企业微信最大化工作区修正测试通过。\n'
