#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"

readonly APP_ID="io.github.loveyu.WeComWine.Deepin"
readonly APP_BRANCH="stable-25.08"
readonly RUNTIME_VERSION="25.08"
readonly ENGINE_VERSION="10.14deepin11"
readonly ENGINE_SHA256="a3412982cfb16d8e20d29508779ac5ad8a3b389a41737eebb7f657a1b5b9cb0f"
readonly ENGINE_URL="https://pro-store-packages.uniontech.com/appstore/pool/appstore/d/deepin-wine10-stable/deepin-wine10-stable_10.14deepin11_amd64.deb"
readonly HELPER_VERSION="5.4.10-1"
readonly HELPER_SHA256="ad23f45e60e574b1eb6bd1964cc0f54e434478e1b3114be6cdb4f0dcfc6caa41"
readonly HELPER_URL="https://pro-store-packages.uniontech.com/appstore/pool/appstore/d/deepin-wine-helper/deepin-wine-helper_5.4.10-1_amd64.deb"
readonly WECOM_ADAPTER_VERSION="5.0.0.6008deepin8"
readonly WECOM_ADAPTER_SHA256="e1ec28e988d5823287dd83ce4715072375314d81af2df5ca5c8ce8f84553010b"
readonly WECOM_ADAPTER_URL="https://pro-store-packages.uniontech.com/appstore/pool/appstore/c/com.qq.weixin.work.deepin/com.qq.weixin.work.deepin_5.0.0.6008deepin8_amd64.deb"
readonly WECOM_VERSION="5.0.10.6025"
readonly WECOM_INSTALLER_SHA256="f9b028420b84dda6888246516e8a1dddd3174eaeb3d8d930e8e04264a9cfa513"
readonly WECOM_INSTALLER_URL="https://dldir1.qq.com/wework/work_weixin/WeCom_5.0.10.6025.exe"
readonly FONT_VERSION="0.2.0-beta-3.1"
readonly FONT_PACKAGE_SHA256="fc23a97e13c0ac783b96710e2ed8e28d8aa34392cc10f3725d0e020392fb0a8a"
readonly FONT_FILE_SHA256="2420e8078af796b19a3f6ef13de527a1a91c1e7171eea115926c614ced1009b3"
readonly FONT_URL="https://community-packages.deepin.com/deepin/beige/pool/main/f/fonts-wqy-microhei/fonts-wqy-microhei_0.2.0-beta-3.1_all.deb"
readonly DEEPIN_REPO="https://community-packages.deepin.com/deepin/beige"
readonly P7ZIP_SHA256="16afa2ffee091743131a235d2662ac2d1d8263a8598f6cb1f9f71134f3c34a32"
readonly P7ZIP_FULL_SHA256="9478c2665cda8f4fe6b7916e122b66205b50012fbc11d63d7c88b9e3fca19221"
readonly LIBCAPI_SHA256="0da60d2219572f7a756adba6eb8bbfdd39efcd3445498e59dd5c72ed8c43ce4e"
readonly LIBGPHOTO_SHA256="e5f82e260738212c21d60da54bf4b686ad475aa9fcb53cdb320dad0e510ac9de"
readonly LIBGPHOTO_PORT_SHA256="b2ed825456f6c9908f59a58a60ebda36a6c07c599803f13af0345e7309d8ca22"
readonly LIBPCSCLITE_SHA256="5e8c144054ad2af3b3d362fcebe8a1d5eed84c1aec7e70310340e8ef5c10f01a"
readonly LIBSANE_SHA256="8430aa2ad6b219903d9033073cf0f80f32f7f2f0366ac56aa2153cff88467c7f"
readonly LIBXML2_SHA256="36b25f4121dd6765f49a5249a94f675139c4fbaae04be5ccc1ac3ae59f1e40c2"
readonly LIBICU74_SHA256="6e57a1e71d4e938663bfb064d370d1e8411dc5f4a5de828c24669f0dc95f6631"
readonly PORTAL_WINE_VERSION="11.0"
readonly PORTAL_WINE_BINARY_SHA256="5c9c3d3625e75e0bbf82d25b1d78020219d952c955e108564484ba42fac309c7"

CACHE_ROOT="${WECOM_DEEPIN_CACHE_DIR:-${XDG_CACHE_HOME}/wecom-flatpak-poc/deepin-engine}"
BUILD_ROOT="${WECOM_DEEPIN_BUILD_DIR:-${CACHE_ROOT}/build-${ENGINE_VERSION}-${WECOM_ADAPTER_VERSION}}"
APP_DIR="${BUILD_ROOT}/appdir"
LOCAL_REPO="${WECOM_DEEPIN_FLATPAK_REPO:-${XDG_DATA_HOME}/wecom-flatpak-poc/deepin-flatpak-repo}"
REMOTE_NAME="${WECOM_DEEPIN_FLATPAK_REMOTE:-wecom-deepin-local}"
ARTIFACT_DIR="${WECOM_DEEPIN_ARTIFACT_DIR:-${PROJECT_DIR}/artifacts/deepin-private}"
SKIP_INSTALL="${WECOM_DEEPIN_SKIP_INSTALL:-0}"
ENGINE_DEB="${WECOM_DEEPIN_ENGINE_DEB:-${CACHE_ROOT}/deepin-wine10-stable_${ENGINE_VERSION}_amd64.deb}"
HELPER_DEB="${WECOM_DEEPIN_HELPER_DEB:-${CACHE_ROOT}/deepin-wine-helper_${HELPER_VERSION}_amd64.deb}"
WECOM_ADAPTER_DEB="${WECOM_DEEPIN_WECOM_DEB:-${CACHE_ROOT}/com.qq.weixin.work.deepin_${WECOM_ADAPTER_VERSION}_amd64.deb}"
WECOM_INSTALLER="${WECOM_DEEPIN_INSTALLER:-${CACHE_ROOT}/WeCom_${WECOM_VERSION}.exe}"
FONT_DEB="${WECOM_DEEPIN_FONT_DEB:-${CACHE_ROOT}/fonts-wqy-microhei_${FONT_VERSION}_all.deb}"
P7ZIP_DEB="${CACHE_ROOT}/p7zip_16.02+dfsg-8_amd64.deb"
P7ZIP_FULL_DEB="${CACHE_ROOT}/p7zip-full_16.02+dfsg-8_amd64.deb"
LIBCAPI_DEB="${CACHE_ROOT}/libcapi20-3_3.27-3_amd64.deb"
LIBGPHOTO_DEB="${CACHE_ROOT}/libgphoto2-6_2.5.27-1_amd64.deb"
LIBGPHOTO_PORT_DEB="${CACHE_ROOT}/libgphoto2-port12_2.5.27-1_amd64.deb"
LIBPCSCLITE_DEB="${CACHE_ROOT}/libpcsclite1_2.3.1-1_amd64.deb"
LIBSANE_DEB="${CACHE_ROOT}/libsane1_1.2.1-5deepin1+rb1_amd64.deb"
LIBXML2_DEB="${CACHE_ROOT}/libxml2_2.9.14+dfsg-1.3+rb2_amd64.deb"
LIBICU74_DEB="${CACHE_ROOT}/libicu74_74.2-1deepin1_amd64.deb"
PORTAL_WINE_FILES="${WECOM_PORTAL_WINE_FILES:-${XDG_CACHE_HOME}/wecom-flatpak-poc/portal-build/11.16-mr10060-f36314a-wecom11/appdir/files}"
BUNDLE_FILE="${ARTIFACT_DIR}/${APP_ID}-wine${PORTAL_WINE_VERSION}-deepin${WECOM_ADAPTER_VERSION}.flatpak"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf '缺少构建命令：%s\n' "$1" >&2
        exit 69
    fi
}

download_verified() {
    local url="$1"
    local output="$2"
    local expected_sha256="$3"
    local referer="${4:-}"
    local actual_sha256=''
    local partial_file=''
    local curl_args=()

    if [[ -f "${output}" ]]; then
        actual_sha256="$(sha256sum "${output}" | awk '{print $1}')"
        if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
            printf '缓存摘要不匹配，拒绝覆盖：%s\n' "${output}" >&2
            printf '期望：%s\n实际：%s\n' "${expected_sha256}" "${actual_sha256}" >&2
            exit 65
        fi
        return
    fi

    install -d "$(dirname -- "${output}")"
    partial_file="${output}.part.$$"
    if [[ -n "${referer}" ]]; then
        curl_args+=(--referer "${referer}")
    fi
    curl --fail --location --retry 10 --retry-all-errors --retry-delay 5 \
        --connect-timeout 30 "${curl_args[@]}" \
        --output "${partial_file}" "${url}"
    printf '%s  %s\n' "${expected_sha256}" "${partial_file}" | sha256sum --check -
    mv "${partial_file}" "${output}"
}

for required_command in 7z curl dpkg-deb flatpak sha256sum; do
    require_command "${required_command}"
done

for required_path in \
    "${PORTAL_WINE_FILES}/bin/wine" \
    "${PORTAL_WINE_FILES}/bin/wineserver" \
    "${PORTAL_WINE_FILES}/lib/wine/i386-unix/ntdll.so" \
    "${PORTAL_WINE_FILES}/lib/wine/x86_64-unix/ntdll.so" \
    "${PORTAL_WINE_FILES}/lib/wine/i386-windows/winebrowser.exe" \
    "${PORTAL_WINE_FILES}/lib/wine/x86_64-windows/winebrowser.exe"; do
    if [[ ! -e "${required_path}" ]]; then
        printf '缺少已验证的 Wine 11 运行文件：%s\n' "${required_path}" >&2
        exit 69
    fi
done
portal_wine_sha256="$(sha256sum "${PORTAL_WINE_FILES}/bin/wine" | awk '{print $1}')"
if [[ "${portal_wine_sha256}" != "${PORTAL_WINE_BINARY_SHA256}" ]]; then
    printf 'Wine 11 运行文件摘要不匹配：%s\n' "${portal_wine_sha256}" >&2
    exit 65
fi
if [[ "$("${PORTAL_WINE_FILES}/bin/wine" --version)" != "wine-${PORTAL_WINE_VERSION}" ]]; then
    printf 'Wine 运行版本不是已验证的 %s。\n' "${PORTAL_WINE_VERSION}" >&2
    exit 65
fi

install -d "${CACHE_ROOT}" "$(dirname -- "${BUILD_ROOT}")"
download_verified "${ENGINE_URL}" "${ENGINE_DEB}" "${ENGINE_SHA256}"
download_verified "${HELPER_URL}" "${HELPER_DEB}" "${HELPER_SHA256}" \
    "https://pro-store-packages.uniontech.com/"
download_verified "${WECOM_ADAPTER_URL}" "${WECOM_ADAPTER_DEB}" "${WECOM_ADAPTER_SHA256}"
download_verified "${WECOM_INSTALLER_URL}" "${WECOM_INSTALLER}" "${WECOM_INSTALLER_SHA256}"
download_verified "${FONT_URL}" "${FONT_DEB}" "${FONT_PACKAGE_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/p/p7zip/p7zip_16.02+dfsg-8_amd64.deb" \
    "${P7ZIP_DEB}" "${P7ZIP_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/p/p7zip/p7zip-full_16.02+dfsg-8_amd64.deb" \
    "${P7ZIP_FULL_DEB}" "${P7ZIP_FULL_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/libc/libcapi20-3/libcapi20-3_3.27-3_amd64.deb" \
    "${LIBCAPI_DEB}" "${LIBCAPI_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/libg/libgphoto2/libgphoto2-6_2.5.27-1_amd64.deb" \
    "${LIBGPHOTO_DEB}" "${LIBGPHOTO_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/libg/libgphoto2/libgphoto2-port12_2.5.27-1_amd64.deb" \
    "${LIBGPHOTO_PORT_DEB}" "${LIBGPHOTO_PORT_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/p/pcsc-lite/libpcsclite1_2.3.1-1_amd64.deb" \
    "${LIBPCSCLITE_DEB}" "${LIBPCSCLITE_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/s/sane-backends/libsane1_1.2.1-5deepin1+rb1_amd64.deb" \
    "${LIBSANE_DEB}" "${LIBSANE_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/libx/libxml2/libxml2_2.9.14+dfsg-1.3+rb2_amd64.deb" \
    "${LIBXML2_DEB}" "${LIBXML2_SHA256}"
download_verified "${DEEPIN_REPO}/pool/main/i/icu/libicu74_74.2-1deepin1_amd64.deb" \
    "${LIBICU74_DEB}" "${LIBICU74_SHA256}"

for runtime_ref in \
    "org.freedesktop.Platform//${RUNTIME_VERSION}" \
    "org.freedesktop.Sdk//${RUNTIME_VERSION}"; do
    if ! flatpak info --user "${runtime_ref}" >/dev/null 2>&1; then
        printf '缺少 Flatpak 运行时：%s\n' "${runtime_ref}" >&2
        printf '请先从已配置的远程仓库安装该运行时。\n' >&2
        exit 69
    fi
done

extract_root="$(mktemp -d "${BUILD_ROOT}.extract.XXXXXX")"
trap 'rm -rf -- "${extract_root}"' EXIT
engine_extract="${extract_root}/engine"
helper_extract="${extract_root}/helper"
adapter_extract="${extract_root}/adapter"
font_extract="${extract_root}/font"
runtime_extract="${extract_root}/runtime"
install -d "${engine_extract}" "${helper_extract}" "${adapter_extract}" \
    "${font_extract}" "${runtime_extract}" \
    "${LOCAL_REPO}" "${ARTIFACT_DIR}"
dpkg-deb --extract "${ENGINE_DEB}" "${engine_extract}"
dpkg-deb --extract "${HELPER_DEB}" "${helper_extract}"
dpkg-deb --extract "${WECOM_ADAPTER_DEB}" "${adapter_extract}"
dpkg-deb --extract "${FONT_DEB}" "${font_extract}"
for runtime_deb in \
    "${P7ZIP_DEB}" "${P7ZIP_FULL_DEB}" "${LIBCAPI_DEB}" \
    "${LIBGPHOTO_DEB}" "${LIBGPHOTO_PORT_DEB}" "${LIBPCSCLITE_DEB}" \
    "${LIBSANE_DEB}" "${LIBXML2_DEB}" "${LIBICU74_DEB}"; do
    dpkg-deb --extract "${runtime_deb}" "${runtime_extract}"
done

engine_source="${engine_extract}/opt/deepin-wine10-stable"
helper_source="${helper_extract}/opt/deepinwine/tools"
adapter_source="${adapter_extract}/opt/apps/com.qq.weixin.work.deepin/files"
font_source="${font_extract}/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"
7z t -bso0 -bsp0 "${adapter_source}/files.7z"
for required_path in \
    "${engine_source}/bin/wine" \
    "${engine_source}/lib/wine/x86_64-unix/ntdll.so" \
    "${helper_source}/gl-wine/gl-wine64" \
    "${helper_source}/gl-wine/gdid3d.reg" \
    "${adapter_source}/dlls/i386-windows/ntdll.dll" \
    "${adapter_source}/dlls/x86_64-unix/ntdll.so" \
    "${adapter_source}/pre_run.sh" \
    "${adapter_source}/pre_update.sh" \
    "${adapter_source}/run.sh" \
    "${adapter_source}/wxworkweb.reg" \
    "${adapter_source}/files.7z"; do
    if [[ ! -e "${required_path}" ]]; then
        printf '官方软件包缺少预期文件：%s\n' "${required_path}" >&2
        exit 65
    fi
done
if ! 7z l "${WECOM_INSTALLER}" | \
    grep -F "FileVersion: ${WECOM_VERSION}" >/dev/null; then
    printf '腾讯官方安装包版本不是预期的 %s。\n' "${WECOM_VERSION}" >&2
    exit 65
fi
printf '%s  %s\n' "${FONT_FILE_SHA256}" "${font_source}" | sha256sum --check -

runtime_dependency_signature="${HELPER_SHA256}:${P7ZIP_SHA256}:${P7ZIP_FULL_SHA256}:${LIBCAPI_SHA256}:${LIBGPHOTO_SHA256}:${LIBGPHOTO_PORT_SHA256}:${LIBPCSCLITE_SHA256}:${LIBSANE_SHA256}:${LIBXML2_SHA256}:${LIBICU74_SHA256}"
build_signature="${APP_ID}:${PORTAL_WINE_BINARY_SHA256}:${WECOM_ADAPTER_SHA256}:${WECOM_INSTALLER_SHA256}:${FONT_PACKAGE_SHA256}:${runtime_dependency_signature}:normal-mode-v17-wine11-system-browser"
if [[ -f "${APP_DIR}/metadata" ]] && \
   { [[ ! -f "${BUILD_ROOT}/signature" ]] || \
     [[ "$(<"${BUILD_ROOT}/signature")" != "${build_signature}" ]]; }; then
    preserved_appdir="${APP_DIR}.previous.$(date +%Y%m%d%H%M%S)"
    mv "${APP_DIR}" "${preserved_appdir}"
    printf '已保留旧 appdir：%s\n' "${preserved_appdir}"
fi

if [[ ! -f "${APP_DIR}/metadata" ]]; then
    flatpak build-init --arch=x86_64 \
        "${APP_DIR}" "${APP_ID}" \
        org.freedesktop.Sdk org.freedesktop.Platform "${RUNTIME_VERSION}"
fi

flatpak build \
    --bind-mount="/run/portal-wine=${PORTAL_WINE_FILES}" \
    --bind-mount="/run/deepin-engine=${engine_source}" \
    --bind-mount="/run/deepin-helper=${helper_source}" \
    --bind-mount="/run/deepin-runtime=${runtime_extract}" \
    --bind-mount="/run/wecom-adapter=${adapter_source}" \
    --bind-mount="/run/wecom-installer=${WECOM_INSTALLER}" \
    --bind-mount="/run/deepin-font=${font_source}" \
    --bind-mount="/run/project=${PROJECT_DIR}" \
    "${APP_DIR}" env LC_ALL=C LANG=C bash -lc '
        set -Eeuo pipefail
        # Start with the complete, previously validated Wine 11 application
        # runtime. This includes both WoW64 halves and winebrowser.exe. Skip
        # the empty i386 extension mount points so a repeated build can update
        # an already-finished appdir without writing through read-only mounts.
        while IFS= read -r -d "" runtime_path; do
            cp -a "${runtime_path}" /app/
        done < <(find /run/portal-wine -mindepth 1 -maxdepth 1 \
            ! -name lib ! -name .ref -print0)
        install -d /app/lib
        while IFS= read -r -d "" runtime_path; do
            cp -a "${runtime_path}" /app/lib/
        done < <(find /run/portal-wine/lib -mindepth 1 -maxdepth 1 \
            ! -name i386-linux-gnu -print0)
        install -d /app/bin \
            /app/share/wecom-deepin/adapter /app/share/wecom-deepin/official \
            /app/share/wecom-deepin/helper/gl-wine \
            /app/share/doc/deepin-wine10-stable \
            /app/share/doc/deepin-wine-helper \
            /app/share/doc/fonts-wqy-microhei \
            /app/lib/deepin-compat /app/lib/p7zip \
            /app/share/fonts/truetype/wqy /app/share/applications \
            /app/share/icons/hicolor/256x256/apps
        # Preserve the complete Deepin application adapter, including its
        # prefix template, WINEPREDLL overlay, registry and pre-run/update
        # helpers.  The Tencent installer updates only the client payload.
        cp -a /run/wecom-adapter/. /app/share/wecom-deepin/adapter/
        # Keep only the helper components used by the normal application
        # startup path.  The Deepin-only DTK updater/banner/uninstaller are
        # intentionally excluded because they are not usable in Flatpak.
        cp -a /run/deepin-helper/gl-wine/. \
            /app/share/wecom-deepin/helper/gl-wine/
        cp -a /run/deepin-runtime/usr/lib/p7zip/. /app/lib/p7zip/
        for command_name in 7z 7za 7zr; do
            ln -sfn "../lib/p7zip/${command_name}" "/app/bin/${command_name}"
        done
        runtime_lib=/run/deepin-runtime/usr/lib/x86_64-linux-gnu
        for library_pattern in \
            "libcapi20.so.3*" \
            "libgphoto2.so.6*" \
            "libgphoto2_port.so.12*" \
            "libpcsclite.so.1" \
            "libpcsclite_real.so.1" \
            "libsane.so.1*" \
            "libxml2.so.2*" \
            "libicuuc.so.74*" \
            "libicudata.so.74*"; do
            cp -a ${runtime_lib}/${library_pattern} /app/lib/deepin-compat/
        done
        install -m 0644 /run/wecom-installer \
            /app/share/wecom-deepin/official/WeCom_5.0.10.6025.exe
        install -m 0644 /run/deepin-font \
            /app/share/fonts/truetype/wqy/wqy-microhei.ttc
        install -m 0755 /run/project/scripts/deepin-wine-wrapper.sh \
            /app/bin/deepin-wine
        install -m 0755 /run/project/scripts/initialize-deepin-prefix.sh \
            /app/share/wecom-deepin/initialize-prefix.sh
        install -m 0755 /run/project/scripts/migrate-deepin-prefix-to-wine11.sh \
            /app/share/wecom-deepin/migrate-prefix-to-wine11.sh
        install -m 0755 /run/project/scripts/install-deepin-official-wecom.sh \
            /app/share/wecom-deepin/install-official-wecom.sh
        install -m 0755 /run/project/scripts/patch-wecom-cef.sh \
            /app/share/wecom-deepin/patch-wecom-cef.sh
        install -m 0755 /run/project/scripts/prepare-deepin-runtime.sh \
            /app/share/wecom-deepin/prepare-runtime.sh
        install -m 0755 /run/project/scripts/run-deepin-package.sh \
            /app/bin/wecom-deepin
        install -m 0644 /run/project/desktop/io.github.loveyu.WeComWine.Deepin.desktop \
            /app/share/applications/io.github.loveyu.WeComWine.Deepin.desktop
        install -m 0644 /run/project/icons/hicolor/256x256/apps/io.github.loveyu.WeComWine.png \
            /app/share/icons/hicolor/256x256/apps/io.github.loveyu.WeComWine.Deepin.png
        # Prevent both explicit and automatic Wine debugger startup.  This is
        # a deliberate product-safety boundary for the WeCom account.
        rm -f /app/bin/winedbg /app/bin/winegdb \
            /app/lib/wine/i386-windows/winedbg.exe \
            /app/lib/wine/x86_64-windows/winedbg.exe
    '

copyright_file="${engine_extract}/usr/share/doc/deepin-wine10-stable/copyright"
if [[ -f "${copyright_file}" ]]; then
    flatpak build --bind-mount="/run/deepin-copyright=${copyright_file}" \
        "${APP_DIR}" install -m 0644 /run/deepin-copyright \
        /app/share/doc/deepin-wine10-stable/copyright
fi

font_copyright_file="${font_extract}/usr/share/doc/fonts-wqy-microhei/copyright"
if [[ -f "${font_copyright_file}" ]]; then
    flatpak build --bind-mount="/run/font-copyright=${font_copyright_file}" \
        "${APP_DIR}" install -m 0644 /run/font-copyright \
        /app/share/doc/fonts-wqy-microhei/copyright
fi

if [[ ! -f "${BUILD_ROOT}/finished" ]] || \
   [[ "$(<"${BUILD_ROOT}/finished")" != "${build_signature}" ]]; then
    gl_merge_dirs='vulkan/icd.d;glvnd/egl_vendor.d;egl/egl_external_platform.d;OpenCL/vendors;lib/dri;lib/d3d;lib/gbm;vulkan/explicit_layer.d;vulkan/implicit_layer.d;vdpau'
    flatpak build-finish \
        --command=wecom-deepin \
        --share=ipc \
        --share=network \
        --socket=x11 \
        --socket=pulseaudio \
        --device=dri \
        --allow=multiarch \
        --filesystem=xdg-download/WeCom:create \
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
        --env=WINEPREFIX=/var/data/wine-wecom-deepin \
        --env=LANG=zh_CN.UTF-8 \
        --env=LC_ALL=zh_CN.UTF-8 \
        --env=XMODIFIERS=@im=fcitx \
        --env=GTK_IM_MODULE=fcitx \
        --env=QT_IM_MODULE=fcitx \
        --env=ATTACH_FILE_DIALOG=1 \
        --env=PATH=/app/bin:/usr/bin \
        --env=LD_LIBRARY_PATH=/app/lib/deepin-compat:/app/lib \
        --env=WINEDLLPATH=/app/lib/wine \
        --env=WINE_WMCLASS=com.qq.weixin.work.deepin \
        "${APP_DIR}"
    printf '%s\n' "${build_signature}" > "${BUILD_ROOT}/finished"
fi
printf '%s\n' "${build_signature}" > "${BUILD_ROOT}/signature"

flatpak build-export --disable-fsync \
    --subject="Wine ${PORTAL_WINE_VERSION} with Deepin WeCom adapter ${WECOM_ADAPTER_VERSION} and official WeCom ${WECOM_VERSION}" \
    "${LOCAL_REPO}" "${APP_DIR}" "${APP_BRANCH}"

repo_url="file://${LOCAL_REPO}"
if flatpak remotes --user --columns=name | grep -Fxq "${REMOTE_NAME}"; then
    flatpak remote-modify --user --url="${repo_url}" "${REMOTE_NAME}"
else
    flatpak remote-add --user --no-gpg-verify "${REMOTE_NAME}" "${repo_url}"
fi

if [[ "${SKIP_INSTALL}" != "1" ]]; then
    flatpak install --user --noninteractive -y --reinstall --no-deps --no-related \
        "${REMOTE_NAME}" "${APP_ID}//${APP_BRANCH}"
fi

flatpak build-bundle --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo \
    "${LOCAL_REPO}" "${BUNDLE_FILE}" "${APP_ID}" "${APP_BRANCH}"
sha256sum "${BUNDLE_FILE}" > "${BUNDLE_FILE}.sha256"

if [[ "${SKIP_INSTALL}" == "1" ]]; then
    printf '已创建（未安装）：%s//%s\n' "${APP_ID}" "${APP_BRANCH}"
else
    printf '已创建并安装：%s//%s\n' "${APP_ID}" "${APP_BRANCH}"
fi
printf '本地私有 Flatpak：%s\n' "${BUNDLE_FILE}"
printf '注意：该制品含官方 Deepin/企业微信适配二进制，不得作为本项目公开附件发布。\n'
