#!/usr/bin/env python3

import argparse
import gzip
import xml.etree.ElementTree as ET
from pathlib import Path

XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"


def normalize_localized_descriptions(parent: ET.Element) -> None:
    for description in list(parent):
        if description.tag != "description":
            normalize_localized_descriptions(description)
            continue

        localized: dict[str, list[ET.Element]] = {}
        for paragraph in list(description):
            language = paragraph.attrib.pop(XML_LANG, None)
            if language:
                description.remove(paragraph)
                localized.setdefault(language, []).append(paragraph)

        insertion_point = list(parent).index(description) + 1
        for language, paragraphs in localized.items():
            translated = ET.Element("description", {XML_LANG: language})
            translated.extend(paragraphs)
            parent.insert(insertion_point, translated)
            insertion_point += 1


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate the deterministic AppStream catalog used by Flatpak repositories."
    )
    parser.add_argument("metainfo", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    component = ET.parse(args.metainfo).getroot()
    if component.tag != "component":
        raise SystemExit(f"expected <component>, got <{component.tag}>")

    metadata_license = component.find("metadata_license")
    if metadata_license is not None:
        component.remove(metadata_license)

    component_id = component.findtext("id")
    if not component_id:
        raise SystemExit("metainfo is missing a component ID")

    normalize_localized_descriptions(component)

    icon = ET.Element("icon", {"type": "cached", "width": "256", "height": "256"})
    icon.text = f"{component_id}.png"
    insertion_point = next(
        (index for index, child in enumerate(component) if child.tag == "launchable"),
        len(component),
    )
    component.insert(insertion_point, icon)

    catalog = ET.Element("components", {"version": "1.0"})
    catalog.append(component)
    ET.indent(catalog, space="  ")
    payload = ET.tostring(catalog, encoding="utf-8", xml_declaration=True)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as output_file:
        with gzip.GzipFile(fileobj=output_file, mode="wb", filename="", mtime=0) as archive:
            archive.write(payload)


if __name__ == "__main__":
    main()
