#!/usr/bin/env bash

set -Eeuo pipefail

target="${1:-}"
if [[ -z "${target}" ]]; then
    exit 64
fi

case "${target}" in
    wecom-select:file:///Z:/*)
        # explorer.exe receives a Wine Z: path. UrlCreateFromPathW preserves
        # that drive in the custom URI; remove it before calling the host
        # FileManager1 API.
        uri="file://${target#wecom-select:file:///Z:}"
        escaped_uri="${uri//\\/\\\\}"
        escaped_uri="${escaped_uri//\'/\\\'}"
        if gdbus call --session \
            --dest org.freedesktop.FileManager1 \
            --object-path /org/freedesktop/FileManager1 \
            --method org.freedesktop.FileManager1.ShowItems \
            "['${escaped_uri}']" '' >/dev/null; then
            exit 0
        fi

        # FileManager1 is optional. Opening the containing directory through
        # OpenURI is still preferable to falling back to Wine Explorer.
        exec xdg-open "${uri%/*}"
        ;;
    wecom-select:*)
        printf '不支持的 Wine Explorer 选择 URI：%s\n' "${target}" >&2
        exit 65
        ;;
    *)
        exec xdg-open "${target}"
        ;;
esac
