#!/usr/bin/env python3

"""Keep managed WeCom X11 windows on the packaged multi-size icon."""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import shutil
import subprocess
import sys
import time
from pathlib import Path


PROPERTY_CHANGE_INTERVAL_SECONDS = 0.25
DESKTOP_FILE_ID = b"io.github.loveyu.WeComWine"
ICON_SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)


def load_icons(project_dir: Path) -> list[int]:
    values: list[int] = []
    magick = shutil.which("magick")
    if magick is None:
        raise RuntimeError("宿主缺少 magick，无法生成 X11 多尺寸窗口图标")

    for size in ICON_SIZES:
        icon_path = (
            project_dir
            / "icons"
            / "hicolor"
            / f"{size}x{size}"
            / "apps"
            / "io.github.loveyu.WeComWine.png"
        )
        if not icon_path.is_file():
            raise RuntimeError(f"缺少企业微信图标：{icon_path}")
        rgba = subprocess.run(
            [magick, str(icon_path), "-depth", "8", "RGBA:-"],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
        expected_bytes = size * size * 4
        if len(rgba) != expected_bytes:
            raise RuntimeError(
                f"企业微信图标像素长度异常：{icon_path} "
                f"expected={expected_bytes} actual={len(rgba)}"
            )

        values.extend((size, size))
        for offset in range(0, len(rgba), 4):
            red, green, blue, alpha = rgba[offset : offset + 4]
            values.append((alpha << 24) | (red << 16) | (green << 8) | blue)

    return values


class X11:
    def __init__(self, icon_values: list[int]) -> None:
        library_name = ctypes.util.find_library("X11") or "libX11.so.6"
        self.lib = ctypes.CDLL(library_name)
        self._configure_functions()
        self._error_handler = self.ERROR_HANDLER(self._ignore_x_error)
        self.lib.XSetErrorHandler(self._error_handler)

        self.display = self.lib.XOpenDisplay(None)
        if not self.display:
            raise RuntimeError("无法连接 X11 DISPLAY")
        self.root = self.lib.XDefaultRootWindow(self.display)
        self.cardinal = self.atom("CARDINAL")
        self.string = self.atom("STRING")
        self.net_client_list = self.atom("_NET_CLIENT_LIST")
        self.net_wm_icon = self.atom("_NET_WM_ICON")
        self.net_wm_state = self.atom("_NET_WM_STATE")
        self.skip_taskbar = self.atom("_NET_WM_STATE_SKIP_TASKBAR")
        self.wm_class = self.atom("WM_CLASS")
        self.kde_desktop_file = self.atom("_KDE_NET_WM_DESKTOP_FILE")
        self.icon_values = icon_values
        self.icon_array = (ctypes.c_ulong * len(icon_values))(*icon_values)
        self.icon_bytes = len(icon_values) * 4

    ERROR_HANDLER = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p)

    @staticmethod
    def _ignore_x_error(_display: ctypes.c_void_p, _event: ctypes.c_void_p) -> int:
        # Windows can disappear between reading _NET_CLIENT_LIST and changing
        # a property. The next scan will operate on the current list.
        return 0

    def _configure_functions(self) -> None:
        self.lib.XOpenDisplay.argtypes = [ctypes.c_char_p]
        self.lib.XOpenDisplay.restype = ctypes.c_void_p
        self.lib.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
        self.lib.XDefaultRootWindow.restype = ctypes.c_ulong
        self.lib.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
        self.lib.XInternAtom.restype = ctypes.c_ulong
        self.lib.XGetWindowProperty.argtypes = [
            ctypes.c_void_p,
            ctypes.c_ulong,
            ctypes.c_ulong,
            ctypes.c_long,
            ctypes.c_long,
            ctypes.c_int,
            ctypes.c_ulong,
            ctypes.POINTER(ctypes.c_ulong),
            ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_ulong),
            ctypes.POINTER(ctypes.c_ulong),
            ctypes.POINTER(ctypes.POINTER(ctypes.c_ubyte)),
        ]
        self.lib.XGetWindowProperty.restype = ctypes.c_int
        self.lib.XChangeProperty.argtypes = [
            ctypes.c_void_p,
            ctypes.c_ulong,
            ctypes.c_ulong,
            ctypes.c_ulong,
            ctypes.c_int,
            ctypes.c_int,
            ctypes.POINTER(ctypes.c_ubyte),
            ctypes.c_int,
        ]
        self.lib.XChangeProperty.restype = ctypes.c_int
        self.lib.XFree.argtypes = [ctypes.c_void_p]
        self.lib.XFree.restype = ctypes.c_int
        self.lib.XFlush.argtypes = [ctypes.c_void_p]
        self.lib.XFlush.restype = ctypes.c_int
        self.lib.XCloseDisplay.argtypes = [ctypes.c_void_p]
        self.lib.XCloseDisplay.restype = ctypes.c_int
        self.lib.XSetErrorHandler.argtypes = [self.ERROR_HANDLER]
        self.lib.XSetErrorHandler.restype = self.ERROR_HANDLER

    def atom(self, name: str) -> int:
        return self.lib.XInternAtom(self.display, name.encode(), 0)

    def get_property(
        self, window: int, property_atom: int, length: int
    ) -> tuple[int, int, int, int, ctypes.POINTER(ctypes.c_ubyte)]:
        actual_type = ctypes.c_ulong()
        actual_format = ctypes.c_int()
        item_count = ctypes.c_ulong()
        bytes_after = ctypes.c_ulong()
        data = ctypes.POINTER(ctypes.c_ubyte)()
        status = self.lib.XGetWindowProperty(
            self.display,
            window,
            property_atom,
            0,
            length,
            0,
            0,
            ctypes.byref(actual_type),
            ctypes.byref(actual_format),
            ctypes.byref(item_count),
            ctypes.byref(bytes_after),
            ctypes.byref(data),
        )
        if status != 0:
            if data:
                self.lib.XFree(data)
            return 0, 0, 0, 0, ctypes.POINTER(ctypes.c_ubyte)()
        return (
            actual_type.value,
            actual_format.value,
            item_count.value,
            bytes_after.value,
            data,
        )

    def client_windows(self) -> list[int]:
        prop_type, prop_format, item_count, bytes_after, data = self.get_property(
            self.root, self.net_client_list, 0
        )
        if data:
            self.lib.XFree(data)
        if prop_type == 0 or prop_format != 32 or bytes_after == 0:
            return []

        length = (bytes_after + 3) // 4
        prop_type, prop_format, item_count, _bytes_after, data = self.get_property(
            self.root, self.net_client_list, length
        )
        if prop_type == 0 or prop_format != 32 or not data:
            if data:
                self.lib.XFree(data)
            return []
        try:
            windows = ctypes.cast(data, ctypes.POINTER(ctypes.c_ulong))
            return [windows[index] for index in range(item_count)]
        finally:
            self.lib.XFree(data)

    def is_wecom_window(self, window: int) -> bool:
        prop_type, prop_format, item_count, _bytes_after, data = self.get_property(
            window, self.wm_class, 64
        )
        if prop_type == 0 or prop_format != 8 or not data:
            if data:
                self.lib.XFree(data)
            return False
        try:
            classes = ctypes.string_at(data, item_count).lower().split(b"\0")
            return b"wxwork.exe" in classes
        finally:
            self.lib.XFree(data)

    def is_taskbar_window(self, window: int) -> bool:
        prop_type, prop_format, item_count, _bytes_after, data = self.get_property(
            window, self.net_wm_state, 64
        )
        if prop_type == 0:
            return True
        if prop_format != 32 or not data:
            if data:
                self.lib.XFree(data)
            return False
        try:
            states = ctypes.cast(data, ctypes.POINTER(ctypes.c_ulong))
            return all(states[index] != self.skip_taskbar for index in range(item_count))
        finally:
            self.lib.XFree(data)

    def icon_is_current(self, window: int) -> bool:
        prop_type, prop_format, item_count, bytes_after, data = self.get_property(
            window, self.net_wm_icon, 0
        )
        if data:
            self.lib.XFree(data)
        return (
            prop_type == self.cardinal
            and prop_format == 32
            and item_count == 0
            and bytes_after == self.icon_bytes
        )

    def set_icon(self, window: int) -> None:
        self.lib.XChangeProperty(
            self.display,
            window,
            self.net_wm_icon,
            self.cardinal,
            32,
            0,
            ctypes.cast(self.icon_array, ctypes.POINTER(ctypes.c_ubyte)),
            len(self.icon_values),
        )
        desktop_file = (ctypes.c_ubyte * len(DESKTOP_FILE_ID)).from_buffer_copy(
            DESKTOP_FILE_ID
        )
        self.lib.XChangeProperty(
            self.display,
            window,
            self.kde_desktop_file,
            self.string,
            8,
            0,
            desktop_file,
            len(DESKTOP_FILE_ID),
        )
        self.lib.XFlush(self.display)

    def normalize(self) -> int:
        changed = 0
        for window in self.client_windows():
            if (
                not self.is_wecom_window(window)
                or not self.is_taskbar_window(window)
                or self.icon_is_current(window)
            ):
                continue
            self.set_icon(window)
            changed += 1
            print(f"企业微信窗口图标已规范化：0x{window:x}", flush=True)
        return changed

    def close(self) -> None:
        if self.display:
            self.lib.XCloseDisplay(self.display)
            self.display = None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()

    project_dir = Path(__file__).resolve().parent.parent
    icon_values = load_icons(project_dir)
    x11 = X11(icon_values)
    try:
        while True:
            x11.normalize()
            if args.once:
                return 0
            time.sleep(PROPERTY_CHANGE_INTERVAL_SECONDS)
    finally:
        x11.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"企业微信窗口图标管理器退出：{error}", file=sys.stderr)
        raise SystemExit(69) from error
