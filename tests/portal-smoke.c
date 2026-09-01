#define COBJMACROS
#define UNICODE
#define _UNICODE

#include <windows.h>
#include <commdlg.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <stdio.h>
#include <stdlib.h>

static DWORD WINAPI watchdog_thread(void *unused)
{
    WCHAR value[32];
    DWORD milliseconds;

    if (!GetEnvironmentVariableW(L"PORTAL_SMOKE_TIMEOUT_MS", value, ARRAYSIZE(value)))
        return 0;
    milliseconds = wcstoul(value, NULL, 10);
    if (milliseconds < 1000 || milliseconds > 60000) return 0;
    Sleep(milliseconds);
    TerminateProcess(GetCurrentProcess(), 124);
    return 0;
}

static int test_legacy_open(void)
{
    WCHAR path[32768] = L"";
    static const WCHAR filter[] = L"Text files\0*.txt\0All files\0*.*\0\0";
    OPENFILENAMEW ofn = {0};

    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = path;
    ofn.nMaxFile = ARRAYSIZE(path);
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_EXPLORER |
                OFN_ALLOWMULTISELECT;
    if (!GetOpenFileNameW(&ofn))
    {
        wprintf(L"cancel-or-error:%lu\n", CommDlgExtendedError());
        return 2;
    }
    wprintf(L"selected:%ls\n", path);
    return 0;
}

static int test_legacy_open_a(void)
{
    char path[32768] = "";
    static const char filter[] = "Text files\0*.txt\0All files\0*.*\0\0";
    OPENFILENAMEA ofn = {0};

    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = path;
    ofn.nMaxFile = ARRAYSIZE(path);
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_EXPLORER;
    if (!GetOpenFileNameA(&ofn)) return 2;
    return 0;
}

static int test_legacy_save(void)
{
    WCHAR path[32768] = L"portal-smoke.txt";
    static const WCHAR filter[] = L"Text files\0*.txt\0All files\0*.*\0\0";
    OPENFILENAMEW ofn = {0};

    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = path;
    ofn.nMaxFile = ARRAYSIZE(path);
    ofn.lpstrDefExt = L"txt";
    ofn.Flags = OFN_PATHMUSTEXIST | OFN_OVERWRITEPROMPT | OFN_EXPLORER;
    if (!GetSaveFileNameW(&ofn))
    {
        wprintf(L"cancel-or-error:%lu\n", CommDlgExtendedError());
        return 2;
    }
    wprintf(L"selected:%ls\n", path);
    return 0;
}

static int test_legacy_save_a(void)
{
    char path[32768] = "portal-smoke-ansi.txt";
    static const char filter[] = "Text files\0*.txt\0All files\0*.*\0\0";
    OPENFILENAMEA ofn = {0};

    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = path;
    ofn.nMaxFile = ARRAYSIZE(path);
    ofn.lpstrDefExt = "txt";
    ofn.Flags = OFN_PATHMUSTEXIST | OFN_OVERWRITEPROMPT | OFN_EXPLORER;
    if (!GetSaveFileNameA(&ofn)) return 2;
    return 0;
}

static UINT_PTR CALLBACK smoke_hook(HWND dialog, UINT message,
                                    WPARAM wparam, LPARAM lparam)
{
    return 0;
}

static int test_hook_fallback(void)
{
    WCHAR path[32768] = L"";
    OPENFILENAMEW ofn = {0};

    ofn.lStructSize = sizeof(ofn);
    ofn.lpstrFile = path;
    ofn.nMaxFile = ARRAYSIZE(path);
    ofn.Flags = OFN_EXPLORER | OFN_ENABLEHOOK;
    ofn.lpfnHook = smoke_hook;
    if (!GetOpenFileNameW(&ofn)) return 2;
    return 0;
}

static int test_browse_folder(void)
{
    WCHAR path[32768] = L"";
    BROWSEINFOW bi = {0};
    PIDLIST_ABSOLUTE pidl;

    bi.lpszTitle = L"Portal folder smoke test";
    bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
    pidl = SHBrowseForFolderW(&bi);
    if (!pidl)
    {
        wprintf(L"cancel-or-error\n");
        return 2;
    }
    if (!SHGetPathFromIDListW(pidl, path))
    {
        CoTaskMemFree(pidl);
        wprintf(L"path-conversion-error\n");
        return 3;
    }
    CoTaskMemFree(pidl);
    wprintf(L"selected:%ls\n", path);
    return 0;
}

static int test_ifile_dialog(BOOL save)
{
    IFileDialog *dialog = NULL;
    IShellItem *item = NULL;
    PWSTR path = NULL;
    HRESULT hr;
    int ret = 1;

    hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (FAILED(hr))
    {
        fwprintf(stderr, L"CoInitializeEx failed: 0x%08lx\n", (unsigned long)hr);
        return 4;
    }
    hr = CoCreateInstance(save ? &CLSID_FileSaveDialog : &CLSID_FileOpenDialog,
                          NULL, CLSCTX_INPROC_SERVER, &IID_IFileDialog,
                          (void **)&dialog);
    if (FAILED(hr))
    {
        fwprintf(stderr, L"CoCreateInstance failed: 0x%08lx\n", (unsigned long)hr);
        goto done;
    }
    hr = IFileDialog_Show(dialog, NULL);
    if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED))
    {
        wprintf(L"cancel\n");
        ret = 2;
        goto done;
    }
    if (FAILED(hr))
    {
        fwprintf(stderr, L"IFileDialog::Show failed: 0x%08lx\n", (unsigned long)hr);
        goto done;
    }
    hr = IFileDialog_GetResult(dialog, &item);
    if (FAILED(hr)) goto done;
    hr = IShellItem_GetDisplayName(item, SIGDN_FILESYSPATH, &path);
    if (FAILED(hr)) goto done;
    wprintf(L"selected:%ls\n", path);
    ret = 0;

done:
    if (path) CoTaskMemFree(path);
    if (item) IShellItem_Release(item);
    if (dialog) IFileDialog_Release(dialog);
    CoUninitialize();
    return ret;
}

static int test_ifile_dialog_constructor(void)
{
    IFileDialog *dialog = NULL;
    HRESULT hr;

    hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (FAILED(hr))
    {
        fwprintf(stderr, L"CoInitializeEx failed: 0x%08lx\n", (unsigned long)hr);
        return 4;
    }
    hr = CoCreateInstance(&CLSID_FileOpenDialog, NULL, CLSCTX_INPROC_SERVER,
                          &IID_IFileDialog, (void **)&dialog);
    if (dialog) IFileDialog_Release(dialog);
    CoUninitialize();
    if (FAILED(hr))
    {
        fwprintf(stderr, L"CoCreateInstance failed: 0x%08lx\n", (unsigned long)hr);
        return 1;
    }
    wprintf(L"constructed\n");
    return 0;
}

int wmain(int argc, WCHAR **argv)
{
    HANDLE watchdog;

    watchdog = CreateThread(NULL, 0, watchdog_thread, NULL, 0, NULL);
    if (watchdog) CloseHandle(watchdog);
    if (argc != 2)
    {
        fwprintf(stderr, L"usage: portal-smoke.exe open|opena|save|savea|folder|ifilecreate|ifileopen|ifilesave|hook\n");
        return 64;
    }
    if (!lstrcmpiW(argv[1], L"open")) return test_legacy_open();
    if (!lstrcmpiW(argv[1], L"opena")) return test_legacy_open_a();
    if (!lstrcmpiW(argv[1], L"save")) return test_legacy_save();
    if (!lstrcmpiW(argv[1], L"savea")) return test_legacy_save_a();
    if (!lstrcmpiW(argv[1], L"folder")) return test_browse_folder();
    if (!lstrcmpiW(argv[1], L"ifilecreate")) return test_ifile_dialog_constructor();
    if (!lstrcmpiW(argv[1], L"ifileopen")) return test_ifile_dialog(FALSE);
    if (!lstrcmpiW(argv[1], L"ifilesave")) return test_ifile_dialog(TRUE);
    if (!lstrcmpiW(argv[1], L"hook")) return test_hook_fallback();
    fwprintf(stderr, L"unknown mode: %ls\n", argv[1]);
    return 64;
}
