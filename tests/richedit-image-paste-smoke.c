#define COBJMACROS
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <ole2.h>
#include <richedit.h>
#include <richole.h>
#include <stdio.h>

struct insert_callback
{
    IRichEditOleCallback iface;
    LONG refs;
    LONG storage_count;
    LONG query_count;
    BOOL standard_rejected;
    BOOL accepted_picture;
    BOOL accepted_storage;
};

static const CLSID CLSID_WeComImage =
{
    0xfa31b4ca, 0x2991, 0x45b2,
    {0xa1, 0xeb, 0x0a, 0x65, 0xd1, 0xf7, 0xd8, 0xda}
};

static inline struct insert_callback *callback_from_iface(IRichEditOleCallback *iface)
{
    return CONTAINING_RECORD(iface, struct insert_callback, iface);
}

static HRESULT STDMETHODCALLTYPE callback_QueryInterface(IRichEditOleCallback *iface,
                                                          REFIID iid, void **object)
{
    if (IsEqualIID(iid, &IID_IUnknown) || IsEqualIID(iid, &IID_IRichEditOleCallback))
    {
        *object = iface;
        iface->lpVtbl->AddRef(iface);
        return S_OK;
    }
    *object = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE callback_AddRef(IRichEditOleCallback *iface)
{
    return InterlockedIncrement(&callback_from_iface(iface)->refs);
}

static ULONG STDMETHODCALLTYPE callback_Release(IRichEditOleCallback *iface)
{
    return InterlockedDecrement(&callback_from_iface(iface)->refs);
}

static HRESULT STDMETHODCALLTYPE callback_GetNewStorage(IRichEditOleCallback *iface,
                                                         IStorage **storage)
{
    struct insert_callback *callback = callback_from_iface(iface);
    ILockBytes *lock_bytes = NULL;
    HRESULT hr;

    callback->storage_count++;
    if (!storage) return E_INVALIDARG;
    *storage = NULL;

    hr = CreateILockBytesOnHGlobal(NULL, TRUE, &lock_bytes);
    if (SUCCEEDED(hr))
    {
        hr = StgCreateDocfileOnILockBytes(lock_bytes,
                                          STGM_CREATE | STGM_READWRITE |
                                          STGM_SHARE_EXCLUSIVE,
                                          0, storage);
        ILockBytes_Release(lock_bytes);
    }
    return hr;
}

static HRESULT STDMETHODCALLTYPE callback_GetInPlaceContext(IRichEditOleCallback *iface,
                                                             IOleInPlaceFrame **frame,
                                                             IOleInPlaceUIWindow **document,
                                                             OLEINPLACEFRAMEINFO *frame_info)
{
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE callback_ShowContainerUI(IRichEditOleCallback *iface, BOOL show)
{
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE callback_QueryInsertObject(IRichEditOleCallback *iface,
                                                             CLSID *clsid, IStorage *storage,
                                                             LONG position)
{
    struct insert_callback *callback = callback_from_iface(iface);

    callback->query_count++;
    if (clsid && IsEqualCLSID(clsid, &CLSID_Picture_EnhMetafile) && storage)
    {
        callback->standard_rejected = TRUE;
        return E_INVALIDARG;
    }

    callback->accepted_picture = clsid && IsEqualCLSID(clsid, &CLSID_WeComImage);
    callback->accepted_storage = storage == NULL;
    return callback->accepted_picture && callback->accepted_storage ? S_OK : E_FAIL;
}

static HRESULT STDMETHODCALLTYPE callback_DeleteObject(IRichEditOleCallback *iface,
                                                        IOleObject *object)
{
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE callback_QueryAcceptData(IRichEditOleCallback *iface,
                                                           IDataObject *object,
                                                           CLIPFORMAT *format, DWORD reco,
                                                           BOOL really, HGLOBAL metapict)
{
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE callback_ContextSensitiveHelp(IRichEditOleCallback *iface,
                                                                BOOL enter_mode)
{
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE callback_GetClipboardData(IRichEditOleCallback *iface,
                                                            CHARRANGE *range, DWORD reco,
                                                            IDataObject **object)
{
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE callback_GetDragDropEffect(IRichEditOleCallback *iface,
                                                             BOOL drag, DWORD key_state,
                                                             DWORD *effect)
{
    if (effect) *effect = DROPEFFECT_COPY;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE callback_GetContextMenu(IRichEditOleCallback *iface,
                                                          WORD selection_type,
                                                          IOleObject *object,
                                                          CHARRANGE *range, HMENU *menu)
{
    return E_NOTIMPL;
}

static IRichEditOleCallbackVtbl callback_vtbl =
{
    callback_QueryInterface,
    callback_AddRef,
    callback_Release,
    callback_GetNewStorage,
    callback_GetInPlaceContext,
    callback_ShowContainerUI,
    callback_QueryInsertObject,
    callback_DeleteObject,
    callback_QueryAcceptData,
    callback_ContextSensitiveHelp,
    callback_GetClipboardData,
    callback_GetDragDropEffect,
    callback_GetContextMenu,
};

int wmain(void)
{
    struct insert_callback callback = {
        {&callback_vtbl}, 1, 0, 0, FALSE, FALSE, FALSE
    };
    IRichEditOle *richole = NULL;
    REOBJECT object = {0};
    HMODULE richedit;
    HWND window;
    HRESULT hr;
    LONG count;
    BOOL class_ok = FALSE;
    BOOL size_ok = FALSE;
    BOOL storage_null = FALSE;

    hr = OleInitialize(NULL);
    if (FAILED(hr))
    {
        wprintf(L"richedit-paste ole-initialize=0x%08lx\n", (unsigned long)hr);
        return 40;
    }

    richedit = LoadLibraryW(L"riched20.dll");
    if (!richedit)
    {
        wprintf(L"richedit-paste load-library-error=%lu\n", GetLastError());
        OleUninitialize();
        return 41;
    }

    window = CreateWindowExW(0, L"RichEdit20W", L"", WS_POPUP | ES_MULTILINE,
                             0, 0, 320, 240, NULL, NULL, GetModuleHandleW(NULL), NULL);
    if (!window)
    {
        wprintf(L"richedit-paste create-window-error=%lu\n", GetLastError());
        FreeLibrary(richedit);
        OleUninitialize();
        return 42;
    }

    SendMessageW(window, EM_SETOLECALLBACK, 0, (LPARAM)&callback.iface);
    SendMessageW(window, WM_PASTE, 0, 0);
    SendMessageW(window, EM_GETOLEINTERFACE, 0, (LPARAM)&richole);
    count = richole ? richole->lpVtbl->GetObjectCount(richole) : -1;

    if (richole && count > 0)
    {
        object.cbStruct = sizeof(object);
        hr = richole->lpVtbl->GetObject(richole, 0, &object, REO_GETOBJ_ALL_INTERFACES);
        if (SUCCEEDED(hr))
        {
            class_ok = IsEqualCLSID(&object.clsid, &CLSID_WeComImage);
            size_ok = object.sizel.cx > 0 && object.sizel.cy > 0;
            storage_null = object.pstg == NULL;
            if (object.poleobj) IOleObject_Release(object.poleobj);
            if (object.pstg) IStorage_Release(object.pstg);
            if (object.polesite) IOleClientSite_Release(object.polesite);
        }
    }

    wprintf(L"richedit-paste storage-count=%ld query-count=%ld standard-rejected=%d "
            L"accepted-picture=%d accepted-null-storage=%d object-count=%ld "
            L"class-ok=%d object-storage-null=%d "
            L"size=%ldx%ld\n",
            callback.storage_count, callback.query_count, callback.standard_rejected,
            callback.accepted_picture, callback.accepted_storage, count, class_ok,
            storage_null,
            object.sizel.cx, object.sizel.cy);

    if (richole) richole->lpVtbl->Release(richole);
    DestroyWindow(window);
    FreeLibrary(richedit);
    OleUninitialize();

    if (!callback.storage_count || !callback.query_count ||
        callback.query_count < 2 || !callback.standard_rejected ||
        !callback.accepted_picture || !callback.accepted_storage || count < 1 ||
        !class_ok || !storage_null || !size_ok)
        return 43;
    return 0;
}
