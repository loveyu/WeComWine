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

CACHE_ROOT="${WECOM_DEEPIN_CACHE_DIR:-${XDG_CACHE_HOME}/wecom-flatpak-poc/deepin-engine}"
BUILD_ROOT="${WECOM_DEEPIN_BUILD_DIR:-${CACHE_ROOT}/build-${ENGINE_VERSION}-${WECOM_ADAPTER_VERSION}}"
APP_DIR="${BUILD_ROOT}/appdir"
LOCAL_REPO="${WECOM_DEEPIN_FLATPAK_REPO:-${XDG_DATA_HOME}/wecom-flatpak-poc/deepin-flatpak-repo}"
REMOTE_NAME="${WECOM_DEEPIN_FLATPAK_REMOTE:-wecom-deepin-local}"
ARTIFACT_DIR="${WECOM_DEEPIN_ARTIFACT_DIR:-${PROJECT_DIR}/artifacts/deepin-private}"
ENGINE_DEB="${WECOM_DEEPIN_ENGINE_DEB:-${CACHE_ROOT}/deepin-wine10-stable_${ENGINE_VERSION}_amd64.deb}"
WECOM_ADAPTER_DEB="${WECOM_DEEPIN_WECOM_DEB:-${CACHE_ROOT}/com.qq.weixin.work.deepin_${WECOM_ADAPTER_VERSION}_amd64.deb}"
WECOM_INSTALLER="${WECOM_DEEPIN_INSTALLER:-${CACHE_ROOT}/WeCom_${WECOM_VERSION}.exe}"
FONT_DEB="${WECOM_DEEPIN_FONT_DEB:-${CACHE_ROOT}/fonts-wqy-microhei_${FONT_VERSION}_all.deb}"
BUNDLE_FILE="${ARTIFACT_DIR}/${APP_ID}-${ENGINE_VERSION}.flatpak"

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
    local actual_sha256=''
    local partial_file=''

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
    curl --fail --location --retry 10 --retry-all-errors --retry-delay 5 \
        --connect-timeout 30 --output "${partial_file}" "${url}"
    printf '%s  %s\n' "${expected_sha256}" "${partial_file}" | sha256sum --check -
    mv "${partial_file}" "${output}"
}

for required_command in 7z curl dpkg-deb flatpak sha256sum; do
    require_command "${required_command}"
done

install -d "${CACHE_ROOT}" "$(dirname -- "${BUILD_ROOT}")"
download_verified "${ENGINE_URL}" "${ENGINE_DEB}" "${ENGINE_SHA256}"
download_verified "${WECOM_ADAPTER_URL}" "${WECOM_ADAPTER_DEB}" "${WECOM_ADAPTER_SHA256}"
download_verified "${WECOM_INSTALLER_URL}" "${WECOM_INSTALLER}" "${WECOM_INSTALLER_SHA256}"
download_verified "${FONT_URL}" "${FONT_DEB}" "${FONT_PACKAGE_SHA256}"

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
adapter_extract="${extract_root}/adapter"
font_extract="${extract_root}/font"
install -d "${engine_extract}" "${adapter_extract}" "${font_extract}" \
    "${LOCAL_REPO}" "${ARTIFACT_DIR}"
dpkg-deb --extract "${ENGINE_DEB}" "${engine_extract}"
dpkg-deb --extract "${WECOM_ADAPTER_DEB}" "${adapter_extract}"
dpkg-deb --extract "${FONT_DEB}" "${font_extract}"

engine_source="${engine_extract}/opt/deepin-wine10-stable"
adapter_source="${adapter_extract}/opt/apps/com.qq.weixin.work.deepin/files"
font_source="${font_extract}/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"
7z t -bso0 -bsp0 "${adapter_source}/files.7z"
for required_path in \
    "${engine_source}/bin/wine" \
    "${engine_source}/lib/wine/x86_64-unix/ntdll.so" \
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

build_signature="${APP_ID}:${ENGINE_SHA256}:${WECOM_ADAPTER_SHA256}:${WECOM_INSTALLER_SHA256}:${FONT_PACKAGE_SHA256}:normal-mode-v11-compat"
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
    --bind-mount="/run/deepin-engine=${engine_source}" \
    --bind-mount="/run/wecom-adapter=${adapter_source}" \
    --bind-mount="/run/wecom-installer=${WECOM_INSTALLER}" \
    --bind-mount="/run/deepin-font=${font_source}" \
    --bind-mount="/run/project=${PROJECT_DIR}" \
    "${APP_DIR}" env LC_ALL=C LANG=C bash -lc '
        set -Eeuo pipefail
        install -d /app/deepin-wine10-stable /app/bin \
            /app/share/wecom-deepin/adapter /app/share/wecom-deepin/official \
            /app/share/doc/deepin-wine10-stable \
            /app/share/doc/fonts-wqy-microhei \
            /app/share/fonts/truetype/wqy /app/share/applications \
            /app/share/icons/hicolor/256x256/apps
        cp -a /run/deepin-engine/. /app/deepin-wine10-stable/
        # Preserve the complete Deepin application adapter, including its
        # prefix template, WINEPREDLL overlay, registry and pre-run/update
        # helpers.  The Tencent installer updates only the client payload.
        cp -a /run/wecom-adapter/. /app/share/wecom-deepin/adapter/
        install -m 0644 /run/wecom-installer \
            /app/share/wecom-deepin/official/WeCom_5.0.10.6025.exe
        install -m 0644 /run/deepin-font \
            /app/share/fonts/truetype/wqy/wqy-microhei.ttc
        install -m 0755 /run/project/scripts/deepin-wine-wrapper.sh \
            /app/bin/deepin-wine
        install -m 0755 /run/project/scripts/initialize-deepin-prefix.sh \
            /app/share/wecom-deepin/initialize-prefix.sh
        install -m 0755 /run/project/scripts/install-deepin-official-wecom.sh \
            /app/share/wecom-deepin/install-official-wecom.sh
        install -m 0755 /run/project/scripts/patch-wecom-cef.sh \
            /app/share/wecom-deepin/patch-wecom-cef.sh
        install -m 0755 /run/project/scripts/run-deepin-package.sh \
            /app/bin/wecom-deepin
        install -m 0644 /run/project/desktop/io.github.loveyu.WeComWine.Deepin.desktop \
            /app/share/applications/io.github.loveyu.WeComWine.Deepin.desktop
        install -m 0644 /run/project/icons/hicolor/256x256/apps/io.github.loveyu.WeComWine.png \
            /app/share/icons/hicolor/256x256/apps/io.github.loveyu.WeComWine.Deepin.png
        ln -sfn deepin-wine /app/bin/wine

        # Deepin installs this engine below /opt and its WoW64 loader embeds
        # that absolute path.  Flatpak application payloads live below /app.
        # Both prefixes are exactly 25 bytes, so an in-place replacement keeps
        # every binary offset intact while allowing 32-bit PE startup.
        while IFS= read -r -d "" candidate; do
            if LC_ALL=C grep -aql "/opt/deepin-wine10-stable" "${candidate}"; then
                perl -pi -e \
                    '\''s{/opt/deepin-wine10-stable}{/app/deepin-wine10-stable}g'\'' \
                    "${candidate}"
            fi
        done < <(find /app/deepin-wine10-stable \
            /app/share/wecom-deepin/adapter/dlls -type f -print0)

        # Prevent both explicit and automatic Wine debugger startup.  This is
        # a deliberate product-safety boundary for the WeCom account.
        rm -f /app/deepin-wine10-stable/bin/winedbg \
            /app/deepin-wine10-stable/lib/wine/i386-windows/winedbg.exe \
            /app/deepin-wine10-stable/lib/wine/x86_64-windows/winedbg.exe
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
    flatpak build-finish \
        --command=wecom-deepin \
        --share=ipc \
        --share=network \
        --socket=x11 \
        --socket=pulseaudio \
        --device=dri \
        --allow=multiarch \
        --filesystem=xdg-download/WeCom:create \
        --env=WINEPREFIX=/var/data/wine-wecom-deepin \
        --env=LANG=zh_CN.UTF-8 \
        --env=LC_ALL=zh_CN.UTF-8 \
        --env=XMODIFIERS=@im=fcitx \
        --env=GTK_IM_MODULE=fcitx \
        --env=QT_IM_MODULE=fcitx \
        --env=ATTACH_FILE_DIALOG=1 \
        --env=PATH=/app/bin:/app/deepin-wine10-stable/bin:/usr/bin \
        --env=WINEDLLPATH=/app/deepin-wine10-stable/lib:/app/deepin-wine10-stable/lib64 \
        --env=WINEPREDLL=/app/share/wecom-deepin/adapter/dlls \
        "${APP_DIR}"
    printf '%s\n' "${build_signature}" > "${BUILD_ROOT}/finished"
fi
printf '%s\n' "${build_signature}" > "${BUILD_ROOT}/signature"

flatpak build-export --disable-fsync \
    --subject="Deepin Wine ${ENGINE_VERSION} adapter ${WECOM_ADAPTER_VERSION} with official WeCom ${WECOM_VERSION}" \
    "${LOCAL_REPO}" "${APP_DIR}" "${APP_BRANCH}"

repo_url="file://${LOCAL_REPO}"
if flatpak remotes --user --columns=name | grep -Fxq "${REMOTE_NAME}"; then
    flatpak remote-modify --user --url="${repo_url}" "${REMOTE_NAME}"
else
    flatpak remote-add --user --no-gpg-verify "${REMOTE_NAME}" "${repo_url}"
fi

flatpak install --user --noninteractive -y --reinstall --no-deps --no-related \
    "${REMOTE_NAME}" "${APP_ID}//${APP_BRANCH}"

flatpak build-bundle --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo \
    "${LOCAL_REPO}" "${BUNDLE_FILE}" "${APP_ID}" "${APP_BRANCH}"
sha256sum "${BUNDLE_FILE}" > "${BUNDLE_FILE}.sha256"

printf '已创建并安装：%s//%s\n' "${APP_ID}" "${APP_BRANCH}"
printf '本地私有 Flatpak：%s\n' "${BUNDLE_FILE}"
printf '注意：该制品含官方 Deepin/企业微信适配二进制，不得作为本项目公开附件发布。\n'
