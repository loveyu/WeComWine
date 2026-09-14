#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
CONFIGURATOR="${PROJECT_DIR}/scripts/configure-emoji-font.sh"
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

prefix="${TEST_ROOT}/prefix"
source_font="${TEST_ROOT}/NotoEmoji-wght.ttf"
wine_mock="${TEST_ROOT}/wine-mock"
wine_log="${TEST_ROOT}/wine.log"
install -d "${prefix}/drive_c/windows/Fonts"
printf 'outline emoji font fixture\n' > "${source_font}"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -Eeuo pipefail' \
    'printf '\''%q '\'' "$@" >> "${WECOM_WINE_MOCK_LOG}"' \
    'printf '\''\n'\'' >> "${WECOM_WINE_MOCK_LOG}"' \
    'if [[ "${1:-}" == reg.exe && "${2:-}" == query ]]; then' \
    '    printf '\''    Tahoma    REG_MULTI_SZ    existing.ttf,Existing\r\n'\''' \
    'fi' > "${wine_mock}"
chmod 0755 "${wine_mock}"

WINEPREFIX="${prefix}" \
WECOM_EMOJI_FONT_SOURCE="${source_font}" \
WECOM_WINE_COMMAND="${wine_mock}" \
WECOM_WINE_MOCK_LOG="${wine_log}" \
    bash "${CONFIGURATOR}"

cmp "${source_font}" \
    "${prefix}/drive_c/windows/Fonts/NotoEmoji-wght.ttf"
grep -Fq 'Noto\ Emoji\ \(TrueType\)' "${wine_log}"
grep -Fq 'REG_MULTI_SZ' "${wine_log}"
grep -Fq '/v Tahoma /t REG_MULTI_SZ' "${wine_log}"
grep -Fq 'existing.ttf\,Existing\\0NotoEmoji-wght.ttf\,Noto\ Emoji' \
    "${wine_log}"
grep -Fq 'Segoe\ UI\ Emoji' "${wine_log}"

# Re-running the repair is safe and restores a damaged prefix-local copy.
printf 'damaged\n' > "${prefix}/drive_c/windows/Fonts/NotoEmoji-wght.ttf"
WINEPREFIX="${prefix}" \
WECOM_EMOJI_FONT_SOURCE="${source_font}" \
WECOM_WINE_COMMAND="${wine_mock}" \
WECOM_WINE_MOCK_LOG="${wine_log}" \
    bash "${CONFIGURATOR}"
cmp "${source_font}" \
    "${prefix}/drive_c/windows/Fonts/NotoEmoji-wght.ttf"
