#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

readonly WINE_VERSION="10.14"
readonly WINE_SOURCE_SHA256="a4fa3b5aefe1c0b7391a91a2c3c733b8dfd04bb315c8eabcfb2af413969e5e4b"
readonly WINE_SOURCE_URL="https://dl.winehq.org/wine/source/10.x/wine-10.14.tar.xz"
readonly PORTAL_PATCHSET="mr10060-wine10-wecom1"
readonly BUILD_APP_ID="io.github.loveyu.WeComWine.Wine10PortalBuild"

STATUS_FILE="${STATE_DIR}/deepin-wine10-portal-build.status"
LOCK_FILE="${STATE_DIR}/deepin-wine10-portal-build.lock"
LOG_FILE="${LOG_DIR}/deepin-wine10-portal-build.log"
BUILD_ROOT="${WECOM_DEEPIN_WINE10_PORTAL_BUILD:-${CACHE_DIR}/deepin-wine10-portal/${WINE_VERSION}-${PORTAL_PATCHSET}}"
SOURCE_DIR="${BUILD_ROOT}/source"
BUILD64_DIR="${BUILD_ROOT}/build64"
BUILD32_DIR="${BUILD_ROOT}/build32"
APP_DIR="${BUILD_ROOT}/appdir"
SOURCE_ARCHIVE="${WECOM_DEEPIN_WINE10_SOURCE_ARCHIVE:-${CACHE_DIR}/wine-${WINE_VERSION}.tar.xz}"
OUTPUT_MANIFEST="${BUILD_ROOT}/output.sha256"
BUILD_JOBS="${BUILD_JOBS:-4}"

patch_files=(
    "${PROJECT_DIR}/patches/wine10-portal/0000-comdlg32-prepare-wine10-include-order.patch"
    "${PROJECT_DIR}/patches/wine-portal/0001-comdlg32-add-XDG-desktop-portal-backend-for-file-dia.patch"
    "${PROJECT_DIR}/patches/wine-portal/0002-comdlg32-route-IFileDialog-through-portal-when-compa.patch"
    "${PROJECT_DIR}/patches/wine-portal/0003-winecfg-add-portal-file-dialog-policy-and-UI.patch"
    "${PROJECT_DIR}/patches/wine-portal/0004-comdlg32-tests-add-IFileOpenDialog-FOS_PICKFOLDERS-r.patch"
    "${PROJECT_DIR}/patches/wine-portal/0005-shell32-route-SHBrowseForFolderW-through-portal-when.patch"
    "${PROJECT_DIR}/patches/wine-portal/0006-comdlg32-avoid-MAX_PATH-truncation-for-portal-items.patch"
    "${PROJECT_DIR}/patches/wine-portal/0007-comdlg32-handle-desktop-folder-initialization-failur.patch"
    "${PROJECT_DIR}/patches/wine-portal/0014-comdlg32-notify-portal-selection-before-file-ok.patch"
    "${PROJECT_DIR}/patches/wine-portal/0015-comdlg32-trace-file-dialog-event-callbacks.patch"
    "${PROJECT_DIR}/patches/wine-portal/0016-comdlg32-expose-portal-results-through-folder-view.patch"
)

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf '缺少 Wine 10 Portal 构建命令：%s\n' "$1" >&2
        exit 69
    fi
}

preserve_path() {
    local path="$1"
    local suffix="${2:-incomplete}"

    if [[ -e "${path}" ]]; then
        mv "${path}" "${path}.${suffix}.$(date +%Y%m%d%H%M%S)"
    fi
}

download_source() {
    local actual_sha256=''
    local attempt=0
    local partial_archive="${SOURCE_ARCHIVE}.part.$$"

    if [[ -f "${SOURCE_ARCHIVE}" ]]; then
        actual_sha256="$(sha256sum "${SOURCE_ARCHIVE}" | awk '{print $1}')"
        if [[ "${actual_sha256}" != "${WINE_SOURCE_SHA256}" ]]; then
            preserve_path "${SOURCE_ARCHIVE}" invalid
        fi
    fi
    if [[ -f "${SOURCE_ARCHIVE}" ]]; then
        return
    fi

    install -d "$(dirname -- "${SOURCE_ARCHIVE}")"
    for attempt in 1 2 3; do
        rm -f -- "${partial_archive}"
        if curl --fail --location --retry 10 --retry-all-errors --retry-delay 5 \
            --connect-timeout 30 --output "${partial_archive}" \
            "${WINE_SOURCE_URL}" && \
           printf '%s  %s\n' "${WINE_SOURCE_SHA256}" "${partial_archive}" | \
               sha256sum --check -; then
            mv "${partial_archive}" "${SOURCE_ARCHIVE}"
            return
        fi
        printf 'Wine %s 源码下载校验失败（第 %s/3 次）。\n' \
            "${WINE_VERSION}" "${attempt}" >&2
    done
    rm -f -- "${partial_archive}"
    return 65
}

verify_output_type() {
    local path="$1"
    local expected_pattern="$2"

    if [[ ! -f "${path}" ]]; then
        printf 'Wine 10 Portal 构建缺少输出：%s\n' "${path}" >&2
        return 69
    fi
    if ! LC_ALL=C file --brief "${path}" | grep -Eq "${expected_pattern}"; then
        printf 'Wine 10 Portal 输出架构不匹配：%s: %s\n' \
            "${path}" "$(LC_ALL=C file --brief "${path}")" >&2
        return 65
    fi
}

for required_command in curl file flatpak flock make patch sha256sum tar; do
    require_command "${required_command}"
done
for patch_file in "${patch_files[@]}"; do
    if [[ ! -f "${patch_file}" ]]; then
        printf '缺少 Wine 10 Portal 补丁：%s\n' "${patch_file}" >&2
        exit 69
    fi
done

rotate_log "${LOG_FILE}" 104857600
exec >> "${LOG_FILE}" 2>&1
exec 9> "${LOCK_FILE}"

if ! flock -n 9; then
    printf '%s Wine 10 Portal build already running\n' "$(date --iso-8601=seconds)"
    exit 75
fi

on_error() {
    local exit_code="$?"
    local line_number="${BASH_LINENO[0]:-unknown}"

    write_status "${STATUS_FILE}" failed "exit=${exit_code},line=${line_number}"
    printf '%s Wine 10 Portal build failed: exit=%s line=%s\n' \
        "$(date --iso-8601=seconds)" "${exit_code}" "${line_number}"
    exit "${exit_code}"
}
trap on_error ERR

printf '%s Wine 10 Portal build start\n' "$(date --iso-8601=seconds)"

write_status "${STATUS_FILE}" install-sdk "org.freedesktop.Sdk//25.08"
sdk_refs=(
    "org.freedesktop.Platform//25.08"
    "org.freedesktop.Sdk//25.08"
    "org.freedesktop.Sdk.Compat.i386//25.08"
    "org.freedesktop.Sdk.Extension.toolchain-i386//25.08"
    "org.freedesktop.Sdk.Extension.mingw-w64//25.08"
)
for sdk_ref in "${sdk_refs[@]}"; do
    if ! flatpak info --user "${sdk_ref}" >/dev/null 2>&1; then
        flatpak install --user --noninteractive -y --no-deps --no-related \
            "${FLATPAK_REMOTE}" "${sdk_ref}"
    fi
done

write_status "${STATUS_FILE}" prepare-source "wine-${WINE_VERSION}-${PORTAL_PATCHSET}"
download_source
printf '%s  %s\n' "${WINE_SOURCE_SHA256}" "${SOURCE_ARCHIVE}" | sha256sum --check -
patch_signature="$(
    {
        printf '%s\n' "${WINE_SOURCE_SHA256}" "${PORTAL_PATCHSET}"
        sha256sum "${patch_files[@]}"
    } | sha256sum | awk '{print $1}'
)"
build_signature="${patch_signature}:new-wow64-shell32-v2"
if [[ ! -f "${SOURCE_DIR}/.portal-patched" ]] || \
   [[ "$(<"${SOURCE_DIR}/.portal-patched")" != "${patch_signature}" ]]; then
    preserve_path "${SOURCE_DIR}"
    preserve_path "${BUILD64_DIR}"
    preserve_path "${BUILD32_DIR}"
    prepare_dir="${BUILD_ROOT}/source.prepare.$$"
    install -d "${prepare_dir}" "${BUILD_ROOT}"
    tar --extract --xz --file="${SOURCE_ARCHIVE}" --strip-components=1 \
        --directory="${prepare_dir}"
    for patch_file in "${patch_files[@]}"; do
        patch --directory="${prepare_dir}" --strip=1 --forward --batch \
            < "${patch_file}"
    done
    printf '%s\n' "${patch_signature}" > "${prepare_dir}/.portal-patched"
    mv "${prepare_dir}" "${SOURCE_DIR}"
fi

output_paths=(
    "build64/dlls/comdlg32/x86_64-windows/comdlg32.dll"
    "build64/dlls/comdlg32/comdlg32.so"
    "build32/dlls/comdlg32/i386-windows/comdlg32.dll"
    "build64/dlls/shell32/x86_64-windows/shell32.dll"
    "build32/dlls/shell32/i386-windows/shell32.dll"
)
if [[ -f "${BUILD_ROOT}/.complete" ]] && \
   [[ "$(<"${BUILD_ROOT}/.complete")" == "${build_signature}" ]] && \
   [[ -f "${OUTPUT_MANIFEST}" ]] && \
   (cd "${BUILD_ROOT}" && sha256sum --check --status "${OUTPUT_MANIFEST}"); then
    write_status "${STATUS_FILE}" complete "${BUILD_ROOT}"
    printf '%s Wine 10 Portal build already complete: %s\n' \
        "$(date --iso-8601=seconds)" "${BUILD_ROOT}"
    exit 0
fi
for output_path in "${output_paths[@]}"; do
    rm -f -- "${BUILD_ROOT}/${output_path}"
done

write_status "${STATUS_FILE}" initialize-appdir "${BUILD_APP_ID}"
install -d "${BUILD64_DIR}" "${BUILD32_DIR}"
if [[ -f "${APP_DIR}/metadata" ]] && \
   ! grep -Fqx "name=${BUILD_APP_ID}" "${APP_DIR}/metadata"; then
    preserve_path "${APP_DIR}" legacy
fi
if [[ ! -f "${APP_DIR}/metadata" ]]; then
    flatpak build-init \
        --arch=x86_64 \
        --sdk-extension=org.freedesktop.Sdk.Compat.i386 \
        --sdk-extension=org.freedesktop.Sdk.Extension.toolchain-i386 \
        --sdk-extension=org.freedesktop.Sdk.Extension.mingw-w64 \
        "${APP_DIR}" "${BUILD_APP_ID}" \
        org.freedesktop.Sdk org.freedesktop.Platform 25.08
fi

write_status "${STATUS_FILE}" build-wine64 "jobs=${BUILD_JOBS}"
flatpak build \
    --allow=devel \
    --bind-mount="/run/build=${BUILD_ROOT}" \
    --env="BUILD_JOBS=${BUILD_JOBS}" \
    "${APP_DIR}" bash -lc '
        set -Eeuo pipefail
        export PATH="/usr/lib/sdk/mingw-w64/bin:${PATH}"
        cd /run/build/build64
        if [[ ! -f Makefile ]]; then
            /run/build/source/configure \
                --prefix=/app \
                --libdir=/app/lib \
                --enable-win64 \
                --with-mingw=x86_64-w64-mingw32-gcc \
                --disable-winemenubuilder \
                --disable-tests \
                --without-opencl
        fi
        make -j"${BUILD_JOBS}" dlls/comdlg32/all dlls/shell32/x86_64-windows/shell32.dll
    '

write_status "${STATUS_FILE}" build-wine32 "jobs=${BUILD_JOBS}"
flatpak build \
    --allow=devel \
    --bind-mount="/run/build=${BUILD_ROOT}" \
    --env="BUILD_JOBS=${BUILD_JOBS}" \
    "${APP_DIR}" bash -lc '
        set -Eeuo pipefail
        export PATH="/usr/lib/sdk/mingw-w64/bin:/usr/lib/sdk/toolchain-i386/bin:${PATH}"
        export CC=i686-unknown-linux-gnu-gcc
        export CXX=i686-unknown-linux-gnu-g++
        export PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
        export LDFLAGS="-L/usr/lib/i386-linux-gnu -Wl,-rpath-link=/usr/lib/i386-linux-gnu -Wl,-z,relro,-z,now -Wl,--as-needed"
        cd /run/build/build32
        if [[ ! -f Makefile ]]; then
            /run/build/source/configure \
                --prefix=/app \
                --bindir=/app/bin32 \
                --libdir=/app/lib \
                --with-wine64=/run/build/build64 \
                --with-mingw=i686-w64-mingw32-gcc \
                --disable-winemenubuilder \
                --disable-tests \
                --without-opencl
        fi
        make -j"${BUILD_JOBS}" dlls/comdlg32/i386-windows/comdlg32.dll \
            dlls/shell32/i386-windows/shell32.dll
    '

write_status "${STATUS_FILE}" verify-output "comdlg32 32/64-bit PE + 64-bit Unix"
verify_output_type \
    "${BUILD64_DIR}/dlls/comdlg32/x86_64-windows/comdlg32.dll" \
    'PE32[+] executable.*x86-64'
verify_output_type \
    "${BUILD64_DIR}/dlls/comdlg32/comdlg32.so" \
    'ELF 64-bit.*x86-64'
verify_output_type \
    "${BUILD32_DIR}/dlls/comdlg32/i386-windows/comdlg32.dll" \
    'PE32 executable.*Intel (i386|80386)'
verify_output_type \
    "${BUILD64_DIR}/dlls/shell32/x86_64-windows/shell32.dll" \
    'PE32[+] executable.*x86-64'
verify_output_type \
    "${BUILD32_DIR}/dlls/shell32/i386-windows/shell32.dll" \
    'PE32 executable.*Intel (i386|80386)'

(cd "${BUILD_ROOT}" && sha256sum "${output_paths[@]}") > "${OUTPUT_MANIFEST}"
(cd "${BUILD_ROOT}" && sha256sum --check "${OUTPUT_MANIFEST}")
printf '%s\n' "${build_signature}" > "${BUILD_ROOT}/.complete"
write_status "${STATUS_FILE}" complete "${BUILD_ROOT}"
printf '%s Wine 10 Portal build complete: %s\n' \
    "$(date --iso-8601=seconds)" "${BUILD_ROOT}"
