from __future__ import annotations

import json
import math
import re
import unicodedata
from pathlib import Path


def resolve_data_dir() -> Path:
    script_path = Path(__file__).resolve()
    project_data = script_path.parents[2] / "data"
    if project_data.exists():
        return project_data
    return script_path.parents[1] / "map_data"


DATA_DIR = resolve_data_dir()
PROVINCES_PATH = DATA_DIR / "provinces.json"

GDP_PATH = Path(r"C:\tmp\gdp_2022.json")
POP_PATH = Path(r"C:\tmp\pop_2022.json")

YEAR = "2022"
MIN_SCORE = 10
MAX_SCORE = 100


MANUAL_NAME_FIXES = {
    "corse-du-sud": "corse-du-sud",
    "haute-corse": "haute-corse",
    "haute rhin": "haut rhin",
    "seien et marne": "seine et marne",
}


def normalize_name(value: str) -> str:
    value = value.replace("艙", "oe").replace("艗", "oe")
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = value.lower()
    value = value.replace("鈥?", "'")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value


def decode_eurostat_values(path: Path) -> tuple[dict[str, float], dict[str, str], dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    ids = data["id"]
    sizes = data["size"]
    geo_axis = ids.index("geo")
    time_axis = ids.index("time")

    geo_dim = data["dimension"]["geo"]["category"]
    time_dim = data["dimension"]["time"]["category"]
    geo_index = geo_dim["index"]
    geo_labels = geo_dim["label"]
    time_index = time_dim["index"]

    values: dict[str, float] = {}
    statuses: dict[str, str] = {}
    raw_values = data.get("value", {})
    raw_status = data.get("status", {})

    def unravel(flat: int) -> list[int]:
        coords = []
        rest = flat
        for size in reversed(sizes):
            coords.append(rest % size)
            rest //= size
        return list(reversed(coords))

    wanted_time_pos = time_index[YEAR]
    geo_by_pos = {pos: code for code, pos in geo_index.items()}

    for flat_key, value in raw_values.items():
        coords = unravel(int(flat_key))
        if coords[time_axis] != wanted_time_pos:
            continue
        geo_code = geo_by_pos[coords[geo_axis]]
        values[geo_code] = value
        if flat_key in raw_status:
            statuses[geo_code] = raw_status[flat_key]

    labels = {code: geo_labels[code] for code in geo_index}
    return values, labels, statuses


def log_scale(value: float, minimum: float, maximum: float) -> int:
    if value <= 0 or minimum <= 0 or maximum <= minimum:
        raise ValueError("log_scale requires positive values and max > min")
    return round(MIN_SCORE + (MAX_SCORE - MIN_SCORE) * math.log(value / minimum) / math.log(maximum / minimum))


def add_compact_stats(data: dict) -> int:
    provinces = data["provinces"]
    gdp_values, gdp_labels, gdp_status = decode_eurostat_values(GDP_PATH)
    pop_values, pop_labels, pop_status = decode_eurostat_values(POP_PATH)

    nuts_by_name: dict[str, str] = {}
    for code, label in gdp_labels.items():
        if not code.startswith("FR"):
            continue
        if code in {"FR", "FRY", "FRM", "FR1", "FRB", "FRC", "FRD", "FRE", "FRF", "FRG", "FRH", "FRI", "FRJ", "FRK", "FRL"}:
            continue
        if len(code) != 5:
            continue
        nuts_by_name[normalize_name(label)] = code

    missing = []
    matched = {}
    for province_id, province in provinces.items():
        key = MANUAL_NAME_FIXES.get(normalize_name(province["name"]), normalize_name(province["name"]))
        nuts_code = nuts_by_name.get(key)
        if nuts_code is None:
            missing.append((province_id, province["name"], key))
            continue

        gdp_million_eur = gdp_values.get(nuts_code)
        population = pop_values.get(nuts_code)
        if gdp_million_eur is None or population is None:
            missing.append((province_id, province["name"], f"no data for {nuts_code}"))
            continue

        matched[province_id] = nuts_code
        province["eurostat_nuts3"] = nuts_code
        province["stats"] = {
            YEAR: {
                "population": {
                    "value": int(population),
                    "unit": "persons",
                },
                "economy": {
                    "gdp_current_market_prices": {
                        "value": float(gdp_million_eur),
                        "unit": "million_eur",
                    },
                    "gdp_per_capita": {
                        "value": round((float(gdp_million_eur) * 1_000_000.0) / float(population), 2),
                        "unit": "eur_per_person",
                    },
                },
            }
        }

    if missing:
        raise RuntimeError(f"Unmatched or missing data: {missing}")

    data.setdefault("meta", {})["stats"] = {
        YEAR: {
            "population_source": "Eurostat demo_r_pjanaggr3, downloaded from the Eurostat dissemination API",
            "economy_source": "Eurostat nama_10r_3gdp, downloaded from the Eurostat dissemination API",
            "population_time_definition": "Population on 1 January",
            "economy_measure": "GDP at current market prices",
            "note": "NUTS3 values were matched to SVG department IDs by normalized department names. Values cover metropolitan departments present in the SVG.",
        }
    }
    data.setdefault("meta", {})["stats_field_policy"] = {
        "province_stats_are_compact": True,
        "kept_per_province": [
            "population.value",
            "population.unit",
            "economy.gdp_current_market_prices.value",
            "economy.gdp_current_market_prices.unit",
            "economy.gdp_per_capita.value",
            "economy.gdp_per_capita.unit",
        ],
        "moved_to_rules_doc": [
            "dataset",
            "measure",
            "filters",
            "status",
        ],
        "rules_doc": "MAP_DATA_RULES.md",
    }
    return len(matched)


def add_game_values(data: dict) -> None:
    provinces = data["provinces"]
    rows = []
    for province_id, province in provinces.items():
        stats = province["stats"][YEAR]
        rows.append(
            {
                "id": province_id,
                "gdp": float(stats["economy"]["gdp_current_market_prices"]["value"]),
                "population": float(stats["population"]["value"]),
            }
        )

    min_gdp = min(row["gdp"] for row in rows)
    max_gdp = max(row["gdp"] for row in rows)
    min_population = min(row["population"] for row in rows)
    max_population = max(row["population"] for row in rows)

    for row in rows:
        provinces[row["id"]]["game_values"] = {
            "tax_base": log_scale(row["gdp"], min_gdp, max_gdp),
            "population_value": log_scale(row["population"], min_population, max_population),
        }

    data.setdefault("meta", {})["game_value_rules"] = {
        "score_range": {"min": MIN_SCORE, "max": MAX_SCORE},
        "tax_base": {
            "source": "stats.2022.economy.gdp_current_market_prices.value",
            "source_unit": "million_eur",
            "formula": "round(10 + 90 * ln(gdp / min_gdp) / ln(max_gdp / min_gdp))",
            "min_gdp": min_gdp,
            "max_gdp": max_gdp,
        },
        "population_value": {
            "source": "stats.2022.population.value",
            "source_unit": "persons",
            "formula": "round(10 + 90 * ln(population / min_population) / ln(max_population / min_population))",
            "min_population": int(min_population),
            "max_population": int(max_population),
        },
    }


def main() -> None:
    data = json.loads(PROVINCES_PATH.read_text(encoding="utf-8"))
    matched_count = add_compact_stats(data)
    add_game_values(data)

    PROVINCES_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"updated={PROVINCES_PATH}")
    print(f"matched_departments={matched_count}")
    for province_id in ["FR75", "FR59", "FR48", "FR23"]:
        province = data["provinces"][province_id]
        stats = province["stats"][YEAR]
        print(
            province_id,
            province["name"],
            province["eurostat_nuts3"],
            stats["population"]["value"],
            stats["economy"]["gdp_current_market_prices"]["value"],
            province["game_values"],
        )


if __name__ == "__main__":
    main()
