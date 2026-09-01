#define COBJMACROS
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <ole2.h>
#include <stdio.h>

static const WCHAR *standard_format_name(UINT format)
{
    switch (format)
    {
    case CF_TEXT: return L"CF_TEXT";
    case CF_BITMAP: return L"CF_BITMAP";
    case CF_METAFILEPICT: return L"CF_METAFILEPICT";
    case CF_SYLK: return L"CF_SYLK";
    case CF_DIF: return L"CF_DIF";
    case CF_TIFF: return L"CF_TIFF";
    case CF_OEMTEXT: return L"CF_OEMTEXT";
    case CF_DIB: return L"CF_DIB";
    case CF_PALETTE: return L"CF_PALETTE";
    case CF_PENDATA: return L"CF_PENDATA";
    case CF_RIFF: return L"CF_RIFF";
    case CF_WAVE: return L"CF_WAVE";
    case CF_UNICODETEXT: return L"CF_UNICODETEXT";
    case CF_ENHMETAFILE: return L"CF_ENHMETAFILE";
    case CF_HDROP: return L"CF_HDROP";
    case CF_LOCALE: return L"CF_LOCALE";
    case CF_DIBV5: return L"CF_DIBV5";
    default: return NULL;
    }
}

int wmain(void)
{
    UINT format = 0;
    UINT png_format;
    unsigned int count = 0;
    HRESULT hr;

    png_format = RegisterClipboardFormatW(L"PNG");

    if (!OpenClipboard(NULL))
    {
        fwprintf(stderr, L"OpenClipboard failed: %lu\n", GetLastError());
        return 1;
    }

    wprintf(L"image-availability bitmap=%d dib=%d dibv5=%d tiff=%d hdrop=%d\n",
            IsClipboardFormatAvailable(CF_BITMAP),
            IsClipboardFormatAvailable(CF_DIB),
            IsClipboardFormatAvailable(CF_DIBV5),
            IsClipboardFormatAvailable(CF_TIFF),
            IsClipboardFormatAvailable(CF_HDROP));
    wprintf(L"registered-png id=%u available=%d\n", png_format,
            png_format ? IsClipboardFormatAvailable(png_format) : 0);

    {
        HANDLE dib = GetClipboardData(CF_DIB);
        const BITMAPINFOHEADER *header = dib ? GlobalLock(dib) : NULL;
        if (header)
        {
            wprintf(L"dib width=%ld height=%ld planes=%u bitcount=%u compression=%lu image-size=%lu header-size=%lu\n",
                    header->biWidth, header->biHeight, header->biPlanes,
                    header->biBitCount, header->biCompression,
                    header->biSizeImage, header->biSize);
            GlobalUnlock(dib);
        }
        else
            wprintf(L"dib-header=unavailable error=%lu\n", GetLastError());
    }

    {
        HBITMAP bitmap = (HBITMAP)GetClipboardData(CF_BITMAP);
        BITMAP metadata = {0};
        if (bitmap && GetObjectW(bitmap, sizeof(metadata), &metadata) == sizeof(metadata))
            wprintf(L"bitmap width=%ld height=%ld planes=%u bitcount=%u row-bytes=%ld\n",
                    metadata.bmWidth, metadata.bmHeight, metadata.bmPlanes,
                    metadata.bmBitsPixel, metadata.bmWidthBytes);
        else
            wprintf(L"bitmap-metadata=unavailable error=%lu\n", GetLastError());
    }

    SetLastError(ERROR_SUCCESS);
    while ((format = EnumClipboardFormats(format)))
    {
        const WCHAR *name = standard_format_name(format);
        WCHAR registered_name[256] = L"";
        HANDLE data;
        SIZE_T size = 0;

        if (!name && format >= 0xc000 &&
            GetClipboardFormatNameW(format, registered_name, ARRAYSIZE(registered_name)))
            name = registered_name;
        if (!name) name = L"<unnamed>";

        data = NULL;
        if (format < 0xc000)
        {
            data = GetClipboardData(format);
            if (data && format != CF_BITMAP && format != CF_PALETTE &&
                format != CF_ENHMETAFILE && format != CF_METAFILEPICT)
                size = GlobalSize(data);
        }
        wprintf(L"format=%u name=%ls available=1 size=%Iu\n", format, name, size);
        count++;
    }
    if (GetLastError() != ERROR_SUCCESS)
        fwprintf(stderr, L"EnumClipboardFormats failed: %lu\n", GetLastError());

    CloseClipboard();
    wprintf(L"format-count=%u\n", count);

    hr = OleInitialize(NULL);
    if (SUCCEEDED(hr))
    {
        IDataObject *object = NULL;
        FORMATETC format_dib = {CF_DIB, NULL, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
        FORMATETC format_bitmap = {CF_BITMAP, NULL, DVASPECT_CONTENT, -1, TYMED_GDI};

        hr = OleGetClipboard(&object);
        wprintf(L"ole-get-clipboard=0x%08lx\n", (unsigned long)hr);
        if (SUCCEEDED(hr) && object)
        {
            wprintf(L"ole-query dib=0x%08lx bitmap=0x%08lx\n",
                    (unsigned long)IDataObject_QueryGetData(object, &format_dib),
                    (unsigned long)IDataObject_QueryGetData(object, &format_bitmap));
            IDataObject_Release(object);
        }
        OleUninitialize();
    }
    else
        wprintf(L"ole-initialize=0x%08lx\n", (unsigned long)hr);
    return 0;
}
