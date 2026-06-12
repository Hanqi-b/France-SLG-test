from __future__ import annotations

import json
from pathlib import Path


def resolve_data_dir() -> Path:
    script_path = Path(__file__).resolve()
    project_data = script_path.parents[2] / "data"
    if project_data.exists():
        return project_data
    return script_path.parents[1] / "map_data"


DATA_DIR = resolve_data_dir()
PROVINCES_PATH = DATA_DIR / "provinces.json"
OLD_OUT = DATA_DIR / "regions_pre_2016.json"
NEW_OUT = DATA_DIR / "regions_post_2016.json"


OLD_REGION_DEPARTMENTS = {
    "alsace": ["FR67", "FR68"],
    "aquitaine": ["FR24", "FR33", "FR40", "FR47", "FR64"],
    "auvergne": ["FR03", "FR15", "FR43", "FR63"],
    "basse_normandie": ["FR14", "FR50", "FR61"],
    "bourgogne": ["FR21", "FR58", "FR71", "FR89"],
    "bretagne": ["FR22", "FR29", "FR35", "FR56"],
    "centre": ["FR18", "FR28", "FR36", "FR37", "FR41", "FR45"],
    "champagne_ardenne": ["FR08", "FR10", "FR51", "FR52"],
    "corse": ["FR2A", "FR2B"],
    "franche_comte": ["FR25", "FR39", "FR70", "FR90"],
    "haute_normandie": ["FR27", "FR76"],
    "ile_de_france": ["FR75", "FR77", "FR78", "FR91", "FR92", "FR93", "FR94", "FR95"],
    "languedoc_roussillon": ["FR11", "FR30", "FR34", "FR48", "FR66"],
    "limousin": ["FR19", "FR23", "FR87"],
    "lorraine": ["FR54", "FR55", "FR57", "FR88"],
    "midi_pyrenees": ["FR09", "FR12", "FR31", "FR32", "FR46", "FR65", "FR81", "FR82"],
    "nord_pas_de_calais": ["FR59", "FR62"],
    "pays_de_la_loire": ["FR44", "FR49", "FR53", "FR72", "FR85"],
    "picardie": ["FR02", "FR60", "FR80"],
    "poitou_charentes": ["FR16", "FR17", "FR79", "FR86"],
    "provence_alpes_cote_d_azur": ["FR04", "FR05", "FR06", "FR13", "FR83", "FR84"],
    "rhone_alpes": ["FR01", "FR07", "FR26", "FR38", "FR42", "FR69", "FR73", "FR74"],
}

OLD_REGION_NAMES = {
    "alsace": "Alsace",
    "aquitaine": "Aquitaine",
    "auvergne": "Auvergne",
    "basse_normandie": "Basse-Normandie",
    "bourgogne": "Bourgogne",
    "bretagne": "Bretagne",
    "centre": "Centre",
    "champagne_ardenne": "Champagne-Ardenne",
    "corse": "Corse",
    "franche_comte": "Franche-Comté",
    "haute_normandie": "Haute-Normandie",
    "ile_de_france": "Île-de-France",
    "languedoc_roussillon": "Languedoc-Roussillon",
    "limousin": "Limousin",
    "lorraine": "Lorraine",
    "midi_pyrenees": "Midi-Pyrénées",
    "nord_pas_de_calais": "Nord-Pas-de-Calais",
    "pays_de_la_loire": "Pays de la Loire",
    "picardie": "Picardie",
    "poitou_charentes": "Poitou-Charentes",
    "provence_alpes_cote_d_azur": "Provence-Alpes-Côte d'Azur",
    "rhone_alpes": "Rhône-Alpes",
}

NEW_REGION_DEPARTMENTS = {
    "auvergne_rhone_alpes": OLD_REGION_DEPARTMENTS["auvergne"] + OLD_REGION_DEPARTMENTS["rhone_alpes"],
    "bourgogne_franche_comte": OLD_REGION_DEPARTMENTS["bourgogne"] + OLD_REGION_DEPARTMENTS["franche_comte"],
    "bretagne": OLD_REGION_DEPARTMENTS["bretagne"],
    "centre_val_de_loire": OLD_REGION_DEPARTMENTS["centre"],
    "corse": OLD_REGION_DEPARTMENTS["corse"],
    "grand_est": OLD_REGION_DEPARTMENTS["alsace"] + OLD_REGION_DEPARTMENTS["champagne_ardenne"] + OLD_REGION_DEPARTMENTS["lorraine"],
    "hauts_de_france": OLD_REGION_DEPARTMENTS["nord_pas_de_calais"] + OLD_REGION_DEPARTMENTS["picardie"],
    "ile_de_france": OLD_REGION_DEPARTMENTS["ile_de_france"],
    "normandie": OLD_REGION_DEPARTMENTS["basse_normandie"] + OLD_REGION_DEPARTMENTS["haute_normandie"],
    "nouvelle_aquitaine": OLD_REGION_DEPARTMENTS["aquitaine"] + OLD_REGION_DEPARTMENTS["limousin"] + OLD_REGION_DEPARTMENTS["poitou_charentes"],
    "occitanie": OLD_REGION_DEPARTMENTS["languedoc_roussillon"] + OLD_REGION_DEPARTMENTS["midi_pyrenees"],
    "pays_de_la_loire": OLD_REGION_DEPARTMENTS["pays_de_la_loire"],
    "provence_alpes_cote_d_azur": OLD_REGION_DEPARTMENTS["provence_alpes_cote_d_azur"],
}

NEW_REGION_NAMES = {
    "auvergne_rhone_alpes": "Auvergne-Rhône-Alpes",
    "bourgogne_franche_comte": "Bourgogne-Franche-Comté",
    "bretagne": "Bretagne",
    "centre_val_de_loire": "Centre-Val de Loire",
    "corse": "Corse",
    "grand_est": "Grand Est",
    "hauts_de_france": "Hauts-de-France",
    "ile_de_france": "Île-de-France",
    "normandie": "Normandie",
    "nouvelle_aquitaine": "Nouvelle-Aquitaine",
    "occitanie": "Occitanie",
    "pays_de_la_loire": "Pays de la Loire",
    "provence_alpes_cote_d_azur": "Provence-Alpes-Côte d'Azur",
}


def build_regions(region_departments: dict[str, list[str]], names: dict[str, str], province_names: dict[str, str]) -> dict:
    return {
        region_id: {
            "id": region_id,
            "name": names[region_id],
            "departments": [
                {
                    "id": department_id,
                    "name": province_names[department_id],
                }
                for department_id in sorted(department_ids)
            ],
        }
        for region_id, department_ids in sorted(region_departments.items())
    }


def validate(region_departments: dict[str, list[str]], expected_ids: set[str], label: str) -> None:
    seen: dict[str, str] = {}
    duplicates: list[tuple[str, str, str]] = []
    for region_id, department_ids in region_departments.items():
        for department_id in department_ids:
            if department_id in seen:
                duplicates.append((department_id, seen[department_id], region_id))
            seen[department_id] = region_id

    assigned = set(seen)
    missing = sorted(expected_ids - assigned)
    extra = sorted(assigned - expected_ids)
    if missing or extra or duplicates:
        raise RuntimeError(
            f"{label} validation failed: missing={missing}, extra={extra}, duplicates={duplicates}"
        )


def main() -> None:
    provinces_data = json.loads(PROVINCES_PATH.read_text(encoding="utf-8"))
    provinces = provinces_data["provinces"]
    province_names = {province_id: province["name"] for province_id, province in provinces.items()}
    expected_ids = set(provinces)

    validate(OLD_REGION_DEPARTMENTS, expected_ids, "pre_2016")
    validate(NEW_REGION_DEPARTMENTS, expected_ids, "post_2016")

    old_output = {
        "meta": {
            "scope": "Metropolitan France departments present in fr_downloaded.svg",
            "period": "pre_2016",
            "region_count": len(OLD_REGION_DEPARTMENTS),
            "department_count": len(expected_ids),
            "note": "This file groups the 96 metropolitan departments from the SVG into the former 22 metropolitan regions used before the 2016 regional reform. Overseas regions/departments are not included because they are not present in the source SVG.",
        },
        "regions": build_regions(OLD_REGION_DEPARTMENTS, OLD_REGION_NAMES, province_names),
    }

    new_output = {
        "meta": {
            "scope": "Metropolitan France departments present in fr_downloaded.svg",
            "period": "post_2016",
            "region_count": len(NEW_REGION_DEPARTMENTS),
            "department_count": len(expected_ids),
            "note": "This file groups the 96 metropolitan departments from the SVG into the 13 metropolitan regions used after the 2016 regional reform. Overseas regions/departments are not included because they are not present in the source SVG.",
        },
        "regions": build_regions(NEW_REGION_DEPARTMENTS, NEW_REGION_NAMES, province_names),
    }

    OLD_OUT.write_text(json.dumps(old_output, ensure_ascii=False, indent=2), encoding="utf-8")
    NEW_OUT.write_text(json.dumps(new_output, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"wrote={OLD_OUT}")
    print(f"pre_2016_regions={len(OLD_REGION_DEPARTMENTS)}")
    print(f"wrote={NEW_OUT}")
    print(f"post_2016_regions={len(NEW_REGION_DEPARTMENTS)}")


if __name__ == "__main__":
    main()
