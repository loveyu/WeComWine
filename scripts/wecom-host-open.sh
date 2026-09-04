#!/usr/bin/env bash

set -Eeuo pipefail

target="${1:-}"
if [[ -z "${target}" ]]; then
    exit 64
fi

gdbus_command="${WECOM_GDBUS_COMMAND:-gdbus}"
xdg_open_command="${WECOM_XDG_OPEN_COMMAND:-xdg-open}"

case "${target}" in
    wecom-select:file:///[Cc]:/*)
        # WeCom stores received files below the C: drive in the private
        # Flatpak Wine prefix. FileManager1 runs on the host, so translate the
        # sandbox's /var/data prefix to its host-visible ~/.var/app location.
        if [[ -z "${FLATPAK_ID:-}" || "${WINEPREFIX:-}" != /var/data/* ]]; then
            printf '无法映射 Flatpak Wine C: 路径：%s\n' "${target}" >&2
            exit 65
        fi
        wine_relative_path="${target#wecom-select:file:///?:}"
        host_prefix="${HOME}/.var/app/${FLATPAK_ID}/data${WINEPREFIX#/var/data}"
        uri="file://${host_prefix}/drive_c${wine_relative_path}"
        ;;
    wecom-select:file:///[Zz]:/*)
        # explorer.exe receives a Wine Z: path. UrlCreateFromPathW preserves
        # that drive in the custom URI; remove it before calling the host
        # FileManager1 API.
        uri="file://${target#wecom-select:file:///?:}"
        ;;
    wecom-select:*)
        printf '不支持的 Wine Explorer 选择 URI：%s\n' "${target}" >&2
        exit 65
        ;;
    *)
        exec "${xdg_open_command}" "${target}"
        ;;
esac

escaped_uri="${uri//\\/\\\\}"
escaped_uri="${escaped_uri//\'/\\\'}"
if "${gdbus_command}" call --session \
    --dest org.freedesktop.FileManager1 \
    --object-path /org/freedesktop/FileManager1 \
    --method org.freedesktop.FileManager1.ShowItems \
    "['${escaped_uri}']" '' >/dev/null; then
    exit 0
fi

# FileManager1 is optional. Opening the containing directory through OpenURI
# is still preferable to falling back to Wine Explorer.
exec "${xdg_open_command}" "${uri%/*}"
