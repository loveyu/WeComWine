#!/usr/bin/env bash

set -Eeuo pipefail

target="${1:-}"
if [[ -z "${target}" ]]; then
    exit 64
fi

gdbus_command="${WECOM_GDBUS_COMMAND:-gdbus}"
xdg_open_command="${WECOM_XDG_OPEN_COMMAND:-xdg-open}"
getfattr_command="${WECOM_GETFATTR_COMMAND:-getfattr}"
python_command="${WECOM_PYTHON_COMMAND:-python3}"

resolve_document_portal_uri() {
    local portal_uri="$1"
    local portal_path=''
    local portal_root=''
    local portal_relative_path=''
    local host_root="${WECOM_DOCUMENT_PORTAL_HOST_PATH:-}"

    portal_path="$("${python_command}" -c \
        'import sys, urllib.parse; print(urllib.parse.unquote(urllib.parse.urlsplit(sys.argv[1]).path))' \
        "${portal_uri}")" || return 1
    if [[ "${portal_path}" =~ ^(/run/user/[[:digit:]]+/doc/[^/]+)/(.*)$ ]] || \
       [[ "${portal_path}" =~ ^(/run/flatpak/doc/[^/]+)/(.*)$ ]]; then
        portal_root="${BASH_REMATCH[1]}"
        portal_relative_path="${BASH_REMATCH[2]}"
    else
        return 1
    fi

    if [[ -z "${host_root}" ]]; then
        host_root="$("${getfattr_command}" --only-values \
            -n user.document-portal.host-path "${portal_root}" 2>/dev/null)" || return 1
    fi
    [[ "${host_root}" == /* && -n "${portal_relative_path}" ]] || return 1

    "${python_command}" -c \
        'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' \
        "${host_root%/}/${portal_relative_path}"
}

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
        # that drive in the custom URI. A Document Portal path exposes only
        # one granted item, so recover its original host path first; this lets
        # the file manager show the complete containing directory.
        uri="file://${target#wecom-select:file:///?:}"
        if host_uri="$(resolve_document_portal_uri "${uri}")"; then
            uri="${host_uri}"
        fi
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
