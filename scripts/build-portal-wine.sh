#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

STATUS_FILE="${STATE_DIR}/portal-build.status"
LOCK_FILE="${STATE_DIR}/portal-build.lock"
LOG_FILE="${LOG_DIR}/portal-build.log"
BUILD_ROOT="${CACHE_DIR}/portal-build/${PORTAL_WINE_VERSION}-${PORTAL_PATCHSET}"
SOURCE_DIR="${BUILD_ROOT}/source"
BUILD64_DIR="${BUILD_ROOT}/build64"
BUILD32_DIR="${BUILD_ROOT}/build32"
APP_DIR="${BUILD_ROOT}/appdir"
SOURCE_ARCHIVE="${CACHE_DIR}/wine-${PORTAL_WINE_VERSION}.tar.xz"
PATCH_DIR="${PROJECT_DIR}/patches/wine-portal"
LOCAL_REMOTE_URL="file://${PORTAL_FLATPAK_REPO}"
BUILD_JOBS="${BUILD_JOBS:-4}"

rotate_log "${LOG_FILE}" 104857600
exec >> "${LOG_FILE}" 2>&1
exec 9> "${LOCK_FILE}"

if ! flock -n 9; then
    printf '%s portal Wine build already running\n' "$(date --iso-8601=seconds)"
    exit 0
fi

on_error() {
    local exit_code="$?"
    local line_number="${BASH_LINENO[0]:-unknown}"

    write_status "${STATUS_FILE}" "failed" "exit=${exit_code},line=${line_number}"
    printf '%s portal Wine build failed: exit=%s line=%s\n' \
        "$(date --iso-8601=seconds)" "${exit_code}" "${line_number}"
    exit "${exit_code}"
}

trap on_error ERR

printf '%s portal Wine build start\n' "$(date --iso-8601=seconds)"

write_status "${STATUS_FILE}" "install-sdk" "org.freedesktop.Sdk//25.08"
sdk_refs=(
    "org.freedesktop.Platform//25.08"
    "org.freedesktop.Sdk//25.08"
    "org.freedesktop.Sdk.Compat.i386//25.08"
    "org.freedesktop.Sdk.Extension.toolchain-i386//25.08"
    "org.freedesktop.Sdk.Extension.mingw-w64//25.08"
    "${FLATPAK_APP}//${FLATPAK_BRANCH}"
)
for sdk_ref in "${sdk_refs[@]}"; do
    if ! flatpak info --user "${sdk_ref}" >/dev/null 2>&1; then
        flatpak install --user --noninteractive -y --no-deps --no-related \
            "${FLATPAK_REMOTE}" "${sdk_ref}"
    fi
done

write_status "${STATUS_FILE}" "prepare-source" "wine-${PORTAL_WINE_VERSION}-${PORTAL_PATCHSET}"
patch_signature="$(sha256sum "${PATCH_DIR}"/*.patch | sha256sum | awk '{print $1}')"
if [[ -f "${SOURCE_ARCHIVE}" ]]; then
    source_sha256="$(sha256sum "${SOURCE_ARCHIVE}" | awk '{print $1}')"
    if [[ "${source_sha256}" != "${PORTAL_WINE_SHA256}" ]]; then
        mv "${SOURCE_ARCHIVE}" "${SOURCE_ARCHIVE}.invalid.$(date +%s)"
    fi
fi
if [[ ! -f "${SOURCE_ARCHIVE}" ]]; then
    curl --fail --location --continue-at - --retry 20 --retry-all-errors \
        --retry-delay 10 --connect-timeout 30 \
        --output "${SOURCE_ARCHIVE}" "${PORTAL_WINE_URL}"
fi
printf '%s  %s\n' "${PORTAL_WINE_SHA256}" "${SOURCE_ARCHIVE}" | sha256sum --check -

if [[ ! -f "${SOURCE_DIR}/.portal-patched" ]] || \
   [[ "$(<"${SOURCE_DIR}/.portal-patched")" != "${patch_signature}" ]]; then
    if [[ -e "${SOURCE_DIR}" ]]; then
        mv "${SOURCE_DIR}" "${SOURCE_DIR}.incomplete.$(date +%s)"
    fi
    prepare_dir="${BUILD_ROOT}/source.prepare.$$"
    mkdir -p "${prepare_dir}" "${BUILD_ROOT}"
    tar --extract --xz --file="${SOURCE_ARCHIVE}" --strip-components=1 --directory="${prepare_dir}"
    for patch_file in "${PATCH_DIR}"/*.patch; do
        if patch --directory="${prepare_dir}" --strip=1 --forward --batch \
            --dry-run < "${patch_file}" >/dev/null 2>&1; then
            patch --directory="${prepare_dir}" --strip=1 --forward --batch \
                < "${patch_file}"
        elif patch --directory="${prepare_dir}" --strip=1 --reverse --batch \
            --dry-run < "${patch_file}" >/dev/null 2>&1; then
            printf 'skip patch already present upstream: %s\n' \
                "${patch_file##*/}"
        else
            printf 'patch conflicts with Wine %s: %s\n' \
                "${PORTAL_WINE_VERSION}" "${patch_file##*/}" >&2
            patch --directory="${prepare_dir}" --strip=1 --forward --batch \
                --dry-run < "${patch_file}" || true
            exit 1
        fi
    done
    printf '%s\n' "${patch_signature}" > "${prepare_dir}/.portal-patched"
    mv "${prepare_dir}" "${SOURCE_DIR}"
fi

write_status "${STATUS_FILE}" "initialize-appdir" "${PORTAL_FLATPAK_APP}"
mkdir -p "${BUILD64_DIR}" "${BUILD32_DIR}" "${PORTAL_FLATPAK_REPO}"
if [[ -f "${APP_DIR}/metadata" ]] && \
   ! grep -Fqx "name=${PORTAL_FLATPAK_APP}" "${APP_DIR}/metadata"; then
    legacy_app_dir="${APP_DIR}.legacy.$(date +%Y%m%d%H%M%S)"
    mv "${APP_DIR}" "${legacy_app_dir}"
    printf 'preserved previous appdir at %s\n' "${legacy_app_dir}"
fi
if [[ ! -f "${APP_DIR}/metadata" ]]; then
    flatpak build-init \
        --arch=x86_64 \
        --base="${FLATPAK_APP}" \
        --base-version="${FLATPAK_BRANCH}" \
        --sdk-extension=org.freedesktop.Sdk.Compat.i386 \
        --sdk-extension=org.freedesktop.Sdk.Extension.toolchain-i386 \
        --sdk-extension=org.freedesktop.Sdk.Extension.mingw-w64 \
        "${APP_DIR}" "${PORTAL_FLATPAK_APP}" \
        org.freedesktop.Sdk org.freedesktop.Platform 25.08
fi

write_status "${STATUS_FILE}" "build-wine64" "jobs=${BUILD_JOBS}"
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
        make -j"${BUILD_JOBS}"
        make install \
            LDCONFIG=/bin/true \
            UPDATE_DESKTOP_DATABASE=/bin/true \
            INSTALL_PROGRAM_FLAGS=-s
    '

write_status "${STATUS_FILE}" "build-wine32" "jobs=${BUILD_JOBS}"
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
        make -j"${BUILD_JOBS}"
        make install \
            LDCONFIG=/bin/true \
            UPDATE_DESKTOP_DATABASE=/bin/true \
            INSTALL_PROGRAM_FLAGS=-s
        # The 32-bit ntdll resolves wineserver relative to bindir.  Both sides
        # of a traditional WoW64 build must talk to the 64-bit wineserver.
        install -d /app/bin32
        ln -sfn ../bin/wineserver /app/bin32/wineserver
    '

write_status "${STATUS_FILE}" "build-smoke-tests" "portal-smoke.exe"
flatpak build \
    --allow=devel \
    --bind-mount="/run/project=${PROJECT_DIR}" \
    "${APP_DIR}" bash -lc '
        set -Eeuo pipefail
        export PATH="/usr/lib/sdk/mingw-w64/bin:${PATH}"
        install -d /app/share/wecom-portal-tests
        install -m 755 /run/project/scripts/configure-prefix-inside-flatpak.sh \
            /app/share/wecom-portal-tests/configure-prefix.sh
        x86_64-w64-mingw32-gcc -municode -O2 -s \
            -o /app/share/wecom-portal-tests/portal-smoke.exe \
            /run/project/tests/portal-smoke.c \
            -lcomdlg32 -lshell32 -lole32 -luuid
        x86_64-w64-mingw32-gcc -municode -mwindows -O2 -s \
            -o /app/share/wecom-portal-tests/ime-smoke.exe \
            /run/project/tests/ime-smoke.c \
            -limm32
        i686-w64-mingw32-gcc -municode -O2 -s \
            -o /app/share/wecom-portal-tests/clipboard-smoke.exe \
            /run/project/tests/clipboard-smoke.c \
            -lole32 -lgdi32
        i686-w64-mingw32-gcc -municode -O2 -s \
            -o /app/share/wecom-portal-tests/richedit-image-paste-smoke.exe \
            /run/project/tests/richedit-image-paste-smoke.c \
            -lole32 -lgdi32 -luuid
    '

write_status "${STATUS_FILE}" "finish-flatpak" "${PORTAL_FLATPAK_APP}"
# Flatpak extensions are mounted below an existing directory in the parent app.
# Keep a marker file so OSTree preserves the otherwise empty mount point.
install -d -m 0755 "${APP_DIR}/files/share/wecom-richedit"
: > "${APP_DIR}/files/share/wecom-richedit/.extension-mount-point"
finish_signature="${PORTAL_FLATPAK_APP}:${PORTAL_PATCHSET}:richedit-extension-v1"
if [[ ! -f "${BUILD_ROOT}/.finished" ]] || \
   [[ "$(<"${BUILD_ROOT}/.finished")" != "${finish_signature}" ]]; then
    gl_merge_dirs='vulkan/icd.d;glvnd/egl_vendor.d;egl/egl_external_platform.d;OpenCL/vendors;lib/dri;lib/d3d;lib/gbm;vulkan/explicit_layer.d;vulkan/implicit_layer.d;vdpau'
    flatpak build-finish \
        --command=wine \
        --share=ipc \
        --share=network \
        --socket=x11 \
        --socket=pulseaudio \
        --device=dri \
        --allow=multiarch \
        --filesystem=xdg-download/WeCom:create \
        --env=WINEPREFIX=/var/data/wine-wecom \
        --extension=org.freedesktop.Platform.Compat.i386=directory=lib/i386-linux-gnu \
        --extension=org.freedesktop.Platform.Compat.i386=version=25.08 \
        --extension=org.freedesktop.Platform.GL32=directory=lib/i386-linux-gnu/GL \
        --extension=org.freedesktop.Platform.GL32=version=1.4 \
        '--extension=org.freedesktop.Platform.GL32=versions=25.08;25.08-extra;1.4' \
        --extension=org.freedesktop.Platform.GL32=subdirectories=true \
        --extension=org.freedesktop.Platform.GL32=no-autodownload=true \
        --extension=org.freedesktop.Platform.GL32=download-if=active-gl-driver \
        --extension=org.freedesktop.Platform.GL32=enable-if=active-gl-driver \
        --extension=org.freedesktop.Platform.GL32=autoprune-unless=active-gl-driver \
        --extension="org.freedesktop.Platform.GL32=merge-dirs=${gl_merge_dirs}" \
        --extension=org.freedesktop.Platform.codecs_extra.i386=directory=lib/i386-linux-gnu/codecs-extra \
        --extension=org.freedesktop.Platform.codecs_extra.i386=version=25.08-extra \
        --extension=org.winehq.Wine.gecko=directory=share/wine/gecko \
        --extension=org.winehq.Wine.mono=directory=share/wine/mono \
        --extension="${RICHEDIT_EXTENSION_ID}=directory=share/wecom-richedit" \
        --extension="${RICHEDIT_EXTENSION_ID}=version=${RICHEDIT_EXTENSION_BRANCH}" \
        --extension="${RICHEDIT_EXTENSION_ID}=no-autodownload=true" \
        --extension="${RICHEDIT_EXTENSION_ID}=autodelete=false" \
        "${APP_DIR}"
    printf '%s\n' "${finish_signature}" > "${BUILD_ROOT}/.finished"
fi

write_status "${STATUS_FILE}" "export-flatpak" "${PORTAL_FLATPAK_REPO}"
flatpak build-export --disable-fsync \
    --subject="Wine ${PORTAL_WINE_VERSION} with MR10060 portal dialogs" \
    "${PORTAL_FLATPAK_REPO}" "${APP_DIR}" "${PORTAL_FLATPAK_BRANCH}"

if ! flatpak remotes --user --columns=name | grep -Fxq "${PORTAL_FLATPAK_REMOTE}"; then
    flatpak remote-add --user --if-not-exists --no-gpg-verify \
        "${PORTAL_FLATPAK_REMOTE}" "${LOCAL_REMOTE_URL}"
else
    flatpak remote-modify --user --url="${LOCAL_REMOTE_URL}" "${PORTAL_FLATPAK_REMOTE}"
fi

write_status "${STATUS_FILE}" "install-flatpak" "${PORTAL_FLATPAK_APP}"
flatpak install --user --noninteractive -y --reinstall --no-deps --no-related \
    "${PORTAL_FLATPAK_REMOTE}" \
    "${PORTAL_FLATPAK_APP}//${PORTAL_FLATPAK_BRANCH}"

write_status "${STATUS_FILE}" "complete" "${PORTAL_FLATPAK_APP}//${PORTAL_FLATPAK_BRANCH}"
printf '%s portal Wine build complete\n' "$(date --iso-8601=seconds)"
