#!/bin/sh

set -eu

# Wine creates the profile shell folders as links to the host XDG folders.
# A deliberately narrow Flatpak sandbox cannot follow most of those links.
# shell32 then fails to construct the Desktop shell folder, and Wine's
# IFileDialog constructor used to dereference the resulting NULL pointer.
# Keep inaccessible folders private to the prefix; files explicitly selected
# through xdg-desktop-portal remain available via the document portal.
isolate_inaccessible_shell_folders()
{
    profile_root="${WINEPREFIX}/drive_c/users"
    for profile_dir in "${profile_root}"/*; do
        [ -d "${profile_dir}" ] || continue
        [ "$(basename "${profile_dir}")" != 'Public' ] || continue

        for shell_folder_name in Desktop Documents Downloads Music Pictures Videos; do
            shell_folder="${profile_dir}/${shell_folder_name}"
            if [ -L "${shell_folder}" ] && [ ! -e "${shell_folder}" ]; then
                link_target="$(readlink "${shell_folder}" || true)"
                unlink "${shell_folder}"
                mkdir -p "${shell_folder}"
                printf 'isolated inaccessible shell folder: %s (was -> %s)\n' \
                    "${shell_folder}" "${link_target}"
            fi
        done
    done
}

# Existing prefixes are repaired before wineboot touches shell folders.  A
# fresh prefix needs one wineboot pass to create its profile, then a second
# pass after inaccessible links have been isolated.
isolate_inaccessible_shell_folders
wineboot --update
wineserver --wait
isolate_inaccessible_shell_folders
wineboot --update
wineserver --wait

wine reg.exe add "HKCU\Software\Wine\X11 Driver" \
    /v FileDialogPortal /t REG_SZ /d auto /f
wine reg.exe add "HKCU\Software\Wine\X11 Driver" \
    /v UseXIM /t REG_SZ /d Y /f
wine reg.exe add "HKCU\Software\Wine\X11 Driver" \
    /v InputStyle /t REG_SZ /d overthespot /f

font_family=''
if [ -r /run/host/fonts/opentype/noto/NotoSansCJK-Regular.ttc ]; then
    font_family='Noto Sans CJK SC'
    wine reg.exe add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts" \
        /v "Noto Sans CJK SC (TrueType)" /t REG_SZ \
        /d "Z:\run\host\fonts\opentype\noto\NotoSansCJK-Regular.ttc" /f
elif [ -r /run/host/fonts/truetype/droid/DroidSansFallbackFull.ttf ]; then
    font_family='Droid Sans Fallback'
    wine reg.exe add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts" \
        /v "Droid Sans Fallback (TrueType)" /t REG_SZ \
        /d "Z:\run\host\fonts\truetype\droid\DroidSansFallbackFull.ttf" /f
fi

if [ -n "${font_family}" ]; then
    for font_name in 'SimSun' 'NSimSun' 'SimHei' 'Microsoft YaHei' \
                     'Microsoft YaHei UI' 'MS Shell Dlg' 'MS Shell Dlg 2'; do
        wine reg.exe add "HKCU\Software\Wine\Fonts\Replacements" \
            /v "${font_name}" /t REG_SZ /d "${font_family}" /f
    done
fi

wineserver --wait
