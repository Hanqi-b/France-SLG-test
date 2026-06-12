from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path


def resolve_project_root() -> Path:
    script_path = Path(__file__).resolve()
    return script_path.parents[2]


PROJECT_ROOT = resolve_project_root()
DATA_DIR = PROJECT_ROOT / "data"
SOURCE_SVG = DATA_DIR / "fr_downloaded.svg"
REGIONS_JSON = DATA_DIR / "regions_post_2016.json"
OUT_SVG = DATA_DIR / "fr_regions_colored.svg"

REGION_PALETTE = [
    "#4f8ad1",
    "#db755c",
    "#5ca880",
    "#bf9138",
    "#9473c2",
    "#63abb8",
    "#cc6b94",
    "#7a9459",
    "#bd7f4d",
    "#739edb",
    "#ad8a61",
    "#8ca3b8",
    "#b37aa3",
]


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def main() -> None:
    regions_data = json.loads(REGIONS_JSON.read_text(encoding="utf-8"))
    region_ids = sorted(regions_data["regions"])

    province_to_color: dict[str, str] = {}
    for index, region_id in enumerate(region_ids):
        color = REGION_PALETTE[index % len(REGION_PALETTE)]
        for department in regions_data["regions"][region_id]["departments"]:
            province_to_color[department["id"]] = color

    ET.register_namespace("", "http://www.w3.org/2000/svg")
    tree = ET.parse(SOURCE_SVG)
    root = tree.getroot()
    root.set("fill", "#6f9c76")
    root.set("stroke", "#111820")
    root.set("stroke-width", ".65")

    for elem in root.iter():
        if local_name(elem.tag) != "path":
            continue
        province_id = elem.attrib.get("id", "")
        if province_id not in province_to_color:
            continue
        elem.set("fill", province_to_color[province_id])
        elem.set("stroke", "#111820")
        elem.set("stroke-width", ".65")

    OUT_SVG.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding="unicode"),
        encoding="utf-8",
    )
    print(f"wrote={OUT_SVG}")
    print(f"colored_departments={len(province_to_color)}")


if __name__ == "__main__":
    main()
