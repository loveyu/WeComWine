#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/image-clipboard-bridge.status"
poll_interval="${WECOM_IMAGE_CLIPBOARD_POLL_INTERVAL:-0.5}"

for command_name in copyq magick xclip timeout; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        write_status "${STATUS_FILE}" "unavailable" "missing=${command_name}"
        printf '%s image clipboard bridge unavailable: missing=%s\n' \
            "$(date --iso-8601=seconds)" "${command_name}"
        exit 0
    fi
done

umask 077
working_dir="$(mktemp -d "${STATE_DIR}/image-clipboard-bridge.XXXXXX")"
png_file="${working_dir}/clipboard.png"
bmp_file="${working_dir}/clipboard.bmp"

cleanup() {
    rm -f -- "${png_file}" "${bmp_file}"
    rmdir -- "${working_dir}" 2>/dev/null || true
}
trap cleanup EXIT TERM INT

last_bitmap_sha256=''
had_image=0
write_status "${STATUS_FILE}" "watching" \
    "source=copyq-current,image/png->image/bmp"

while :; do
    : > "${png_file}"
    if timeout 2s copyq clipboard image/png > "${png_file}" 2>/dev/null && \
       [[ -s "${png_file}" ]] && \
       magick "${png_file}" "bmp3:${bmp_file}" 2>/dev/null && \
       [[ -s "${bmp_file}" ]]; then
        bitmap_sha256="$(sha256sum "${bmp_file}" | awk '{print $1}')"
        if (( had_image == 0 )) || \
           [[ "${bitmap_sha256}" != "${last_bitmap_sha256}" ]]; then
            if xclip -selection clipboard -target image/bmp -in \
                < "${bmp_file}"; then
                dimensions="$(magick identify -format '%wx%h' \
                    "${png_file}" 2>/dev/null || printf 'unknown')"
                write_status "${STATUS_FILE}" "bridged" \
                    "source=copyq-current,format=image/bmp,size=${dimensions}"
                printf '%s image clipboard bridged as BMP size=%s\n' \
                    "$(date --iso-8601=seconds)" "${dimensions}"
            else
                write_status "${STATUS_FILE}" "failed" "xclip=image/bmp"
            fi
        fi
        last_bitmap_sha256="${bitmap_sha256}"
        had_image=1
    else
        last_bitmap_sha256=''
        had_image=0
    fi

    rm -f -- "${png_file}" "${bmp_file}"
    sleep "${poll_interval}"
done
