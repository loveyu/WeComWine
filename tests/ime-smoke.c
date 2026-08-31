#define UNICODE
#define _UNICODE

#include <windows.h>
#include <imm.h>
#include <stdio.h>

static HWND edit_control;
static HWND log_control;
static FILE *status_file;
static HFONT cjk_font;
static WCHAR last_edit_text[160];

static void status_log(const WCHAR *message, DWORD value)
{
    if (!status_file) return;
    fwprintf(status_file, L"%ls: %lu (0x%08lx)\n", message,
             (unsigned long)value, (unsigned long)value);
    fflush(status_file);
}

static void append_log(const WCHAR *message)
{
    int length = GetWindowTextLengthW(log_control);
    SendMessageW(log_control, EM_SETSEL, length, length);
    SendMessageW(log_control, EM_REPLACESEL, FALSE, (LPARAM)message);
}

static void log_edit_text(void)
{
    WCHAR buffer[160];
    int length = GetWindowTextW(edit_control, buffer, ARRAYSIZE(buffer));
    int i;

    if (!status_file || !length || !wcscmp(buffer, last_edit_text)) return;
    lstrcpynW(last_edit_text, buffer, ARRAYSIZE(last_edit_text));
    fwprintf(status_file, L"edit_text_length: %d\nedit_text_utf16:", length);
    for (i = 0; i < length; ++i) fwprintf(status_file, L" %04x", buffer[i]);
    fwprintf(status_file, L"\n");
    fflush(status_file);
}

static LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam)
{
    WCHAR buffer[160];

    switch (message)
    {
    case WM_IME_STARTCOMPOSITION:
        append_log(L"WM_IME_STARTCOMPOSITION\r\n");
        break;
    case WM_IME_COMPOSITION:
        swprintf(buffer, ARRAYSIZE(buffer), L"WM_IME_COMPOSITION lParam=0x%08lx\r\n",
                 (unsigned long)lparam);
        append_log(buffer);
        if (lparam & GCS_RESULTSTR) PostMessageW(window, WM_APP, 0, 0);
        break;
    case WM_IME_ENDCOMPOSITION:
        append_log(L"WM_IME_ENDCOMPOSITION\r\n");
        break;
    case WM_INPUTLANGCHANGE:
        swprintf(buffer, ARRAYSIZE(buffer), L"WM_INPUTLANGCHANGE charset=%lu\r\n",
                 (unsigned long)wparam);
        append_log(buffer);
        break;
    case WM_APP:
        log_edit_text();
        return 0;
    case WM_TIMER:
        log_edit_text();
        return 0;
    case WM_DESTROY:
        KillTimer(window, 1);
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(window, message, wparam, lparam);
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, WCHAR *command_line, int show)
{
    WNDCLASSW window_class = {0};
    HWND window;
    MSG message;

    status_file = _wfopen(L"C:\\wecom-ime-smoke-status.txt", L"w");
    status_log(L"started", 1);
    window_class.lpfnWndProc = window_proc;
    window_class.hInstance = instance;
    window_class.hCursor = LoadCursorW(NULL, IDC_IBEAM);
    window_class.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    window_class.lpszClassName = L"WineFcitx5ImeSmoke";
    if (!RegisterClassW(&window_class))
    {
        status_log(L"RegisterClassW failed", GetLastError());
        return 1;
    }

    window = CreateWindowExW(0, window_class.lpszClassName,
        L"Wine Fcitx5 IME Smoke", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 650, 390,
        NULL, NULL, instance, NULL);
    if (!window)
    {
        status_log(L"CreateWindowExW failed", GetLastError());
        return 2;
    }
    status_log(L"window", 1);
    edit_control = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
        16, 18, 600, 30, window, (HMENU)1, instance, NULL);
    log_control = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", L"",
        WS_CHILD | WS_VISIBLE | ES_MULTILINE | ES_AUTOVSCROLL |
        ES_READONLY | WS_VSCROLL,
        16, 62, 600, 260, window, (HMENU)2, instance, NULL);
    status_log(L"edit_control", edit_control != NULL);
    status_log(L"log_control", log_control != NULL);
    cjk_font = CreateFontW(-20, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Microsoft YaHei");
    status_log(L"cjk_font", cjk_font != NULL);
    if (cjk_font)
    {
        SendMessageW(edit_control, WM_SETFONT, (WPARAM)cjk_font, TRUE);
        SendMessageW(log_control, WM_SETFONT, (WPARAM)cjk_font, TRUE);
    }
    SetFocus(edit_control);
    append_log(L"Focus the first field and type Chinese with Fcitx5.\r\n");
    SetTimer(window, 1, 500, NULL);
    ShowWindow(window, show);
    UpdateWindow(window);

    while (GetMessageW(&message, NULL, 0, 0) > 0)
    {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    status_log(L"exiting", (DWORD)message.wParam);
    if (cjk_font) DeleteObject(cjk_font);
    if (status_file) fclose(status_file);
    return (int)message.wParam;
}
