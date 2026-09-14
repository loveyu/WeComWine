#define COBJMACROS
#define INITGUID

#include <windows.h>
#include <dwrite.h>
#include <stdio.h>

int wmain(int argc, WCHAR **argv)
{
    static const UINT32 codepoints[] = {
        0x1f44d, 0x1f600, 0x1f642, 0x1f680, 0x1f923, 0x1fae0
    };
    UINT16 glyphs[sizeof(codepoints) / sizeof(codepoints[0])] = {0};
    IDWriteFactory *factory = NULL;
    IDWriteFontCollection *collection = NULL;
    IDWriteFontFamily *family = NULL;
    IDWriteFont *font = NULL;
    IDWriteFontFace *face = NULL;
    UINT32 family_index = 0;
    BOOL family_exists = FALSE;
    HRESULT hr;
    unsigned int i;
    int failures = 0;

    if (argc != 2)
    {
        fwprintf(stderr, L"usage: %ls FONT-FAMILY\n", argv[0]);
        return 64;
    }

    hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_ISOLATED,
                             &IID_IDWriteFactory,
                             (IUnknown **)&factory);
    if (FAILED(hr))
    {
        fwprintf(stderr, L"DWriteCreateFactory failed: 0x%08lx\n", hr);
        return 1;
    }
    hr = IDWriteFactory_GetSystemFontCollection(factory, &collection, FALSE);
    if (FAILED(hr))
    {
        fwprintf(stderr, L"GetSystemFontCollection failed: 0x%08lx\n", hr);
        failures++;
        goto done;
    }
    hr = IDWriteFontCollection_FindFamilyName(collection, argv[1],
                                               &family_index, &family_exists);
    if (FAILED(hr) || !family_exists)
    {
        fwprintf(stderr, L"font family not found: %ls (0x%08lx)\n",
                 argv[1], hr);
        failures++;
        goto done;
    }
    hr = IDWriteFontCollection_GetFontFamily(collection, family_index, &family);
    if (SUCCEEDED(hr))
        hr = IDWriteFontFamily_GetFirstMatchingFont(
            family, DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL,
            DWRITE_FONT_STYLE_NORMAL, &font);
    if (SUCCEEDED(hr)) hr = IDWriteFont_CreateFontFace(font, &face);
    if (FAILED(hr))
    {
        fwprintf(stderr, L"CreateFontFace failed: 0x%08lx\n", hr);
        failures++;
        goto done;
    }

    hr = IDWriteFontFace_GetGlyphIndices(
        face, codepoints, sizeof(codepoints) / sizeof(codepoints[0]), glyphs);
    if (FAILED(hr))
    {
        fwprintf(stderr, L"GetGlyphIndices failed: 0x%08lx\n", hr);
        failures++;
        goto done;
    }
    for (i = 0; i < sizeof(codepoints) / sizeof(codepoints[0]); ++i)
    {
        wprintf(L"U+%04X glyph=%u\n", codepoints[i], glyphs[i]);
        if (!glyphs[i]) failures++;
    }

done:
    if (face) IDWriteFontFace_Release(face);
    if (font) IDWriteFont_Release(font);
    if (family) IDWriteFontFamily_Release(family);
    if (collection) IDWriteFontCollection_Release(collection);
    IDWriteFactory_Release(factory);
    return failures ? 2 : 0;
}
