from __future__ import annotations

import json
import math
import re
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


def resolve_data_dir() -> Path:
    script_path = Path(__file__).resolve()
    project_data = script_path.parents[2] / "data"
    if project_data.exists():
        return project_data
    return script_path.parents[1] / "map_data"


DATA_DIR = resolve_data_dir()
SVG_PATH = DATA_DIR / "fr_downloaded.svg"
OUT_PATH = DATA_DIR / "provinces.json"

TOKEN_RE = re.compile(r"[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def to_float(value: str | None, default: float = 0.0) -> float:
    if value is None:
        return default
    return float(value)


def pair_key(a: str, b: str) -> tuple[str, str]:
    return (a, b) if a < b else (b, a)


def sample_line(points: list[tuple[float, float]], start: tuple[float, float], end: tuple[float, float], step: float = 2.0) -> None:
    sx, sy = start
    ex, ey = end
    length = math.hypot(ex - sx, ey - sy)
    parts = max(1, int(math.ceil(length / step)))
    for i in range(1, parts + 1):
        t = i / parts
        points.append((sx + (ex - sx) * t, sy + (ey - sy) * t))


def cubic(p0, p1, p2, p3, t: float) -> tuple[float, float]:
    mt = 1.0 - t
    x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
    y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
    return x, y


def quadratic(p0, p1, p2, t: float) -> tuple[float, float]:
    mt = 1.0 - t
    x = mt**2 * p0[0] + 2 * mt * t * p1[0] + t**2 * p2[0]
    y = mt**2 * p0[1] + 2 * mt * t * p1[1] + t**2 * p2[1]
    return x, y


def parse_path_points(d: str) -> list[tuple[float, float]]:
    tokens = TOKEN_RE.findall(d)
    i = 0
    cmd = ""
    current = (0.0, 0.0)
    start = (0.0, 0.0)
    last_cubic_ctrl: tuple[float, float] | None = None
    last_quad_ctrl: tuple[float, float] | None = None
    points: list[tuple[float, float]] = []

    def has_number() -> bool:
        return i < len(tokens) and not re.fullmatch(r"[A-Za-z]", tokens[i])

    def read_num() -> float:
        nonlocal i
        value = float(tokens[i])
        i += 1
        return value

    while i < len(tokens):
        if re.fullmatch(r"[A-Za-z]", tokens[i]):
            cmd = tokens[i]
            i += 1

        if cmd in "Mm":
            first = True
            while has_number():
                x, y = read_num(), read_num()
                if cmd == "m":
                    x += current[0]
                    y += current[1]
                end = (x, y)
                if first:
                    current = end
                    start = end
                    points.append(end)
                    first = False
                else:
                    sample_line(points, current, end)
                    current = end
                last_cubic_ctrl = None
                last_quad_ctrl = None
            cmd = "l" if cmd == "m" else "L"

        elif cmd in "Ll":
            while has_number():
                x, y = read_num(), read_num()
                if cmd == "l":
                    x += current[0]
                    y += current[1]
                end = (x, y)
                sample_line(points, current, end)
                current = end
                last_cubic_ctrl = None
                last_quad_ctrl = None

        elif cmd in "Hh":
            while has_number():
                x = read_num()
                if cmd == "h":
                    x += current[0]
                end = (x, current[1])
                sample_line(points, current, end)
                current = end
                last_cubic_ctrl = None
                last_quad_ctrl = None

        elif cmd in "Vv":
            while has_number():
                y = read_num()
                if cmd == "v":
                    y += current[1]
                end = (current[0], y)
                sample_line(points, current, end)
                current = end
                last_cubic_ctrl = None
                last_quad_ctrl = None

        elif cmd in "Cc":
            while has_number():
                x1, y1, x2, y2, x, y = [read_num() for _ in range(6)]
                if cmd == "c":
                    x1 += current[0]
                    y1 += current[1]
                    x2 += current[0]
                    y2 += current[1]
                    x += current[0]
                    y += current[1]
                p0, p1, p2, p3 = current, (x1, y1), (x2, y2), (x, y)
                approx_len = math.hypot(x - current[0], y - current[1])
                parts = max(8, int(math.ceil(approx_len / 2.0)))
                for n in range(1, parts + 1):
                    points.append(cubic(p0, p1, p2, p3, n / parts))
                current = p3
                last_cubic_ctrl = p2
                last_quad_ctrl = None

        elif cmd in "Ss":
            while has_number():
                if last_cubic_ctrl:
                    x1 = 2 * current[0] - last_cubic_ctrl[0]
                    y1 = 2 * current[1] - last_cubic_ctrl[1]
                else:
                    x1, y1 = current
                x2, y2, x, y = [read_num() for _ in range(4)]
                if cmd == "s":
                    x2 += current[0]
                    y2 += current[1]
                    x += current[0]
                    y += current[1]
                p0, p1, p2, p3 = current, (x1, y1), (x2, y2), (x, y)
                parts = max(8, int(math.ceil(math.hypot(x - current[0], y - current[1]) / 2.0)))
                for n in range(1, parts + 1):
                    points.append(cubic(p0, p1, p2, p3, n / parts))
                current = p3
                last_cubic_ctrl = p2
                last_quad_ctrl = None

        elif cmd in "Qq":
            while has_number():
                x1, y1, x, y = [read_num() for _ in range(4)]
                if cmd == "q":
                    x1 += current[0]
                    y1 += current[1]
                    x += current[0]
                    y += current[1]
                p0, p1, p2 = current, (x1, y1), (x, y)
                parts = max(8, int(math.ceil(math.hypot(x - current[0], y - current[1]) / 2.0)))
                for n in range(1, parts + 1):
                    points.append(quadratic(p0, p1, p2, n / parts))
                current = p2
                last_quad_ctrl = p1
                last_cubic_ctrl = None

        elif cmd in "Tt":
            while has_number():
                if last_quad_ctrl:
                    x1 = 2 * current[0] - last_quad_ctrl[0]
                    y1 = 2 * current[1] - last_quad_ctrl[1]
                else:
                    x1, y1 = current
                x, y = read_num(), read_num()
                if cmd == "t":
                    x += current[0]
                    y += current[1]
                p0, p1, p2 = current, (x1, y1), (x, y)
                parts = max(8, int(math.ceil(math.hypot(x - current[0], y - current[1]) / 2.0)))
                for n in range(1, parts + 1):
                    points.append(quadratic(p0, p1, p2, n / parts))
                current = p2
                last_quad_ctrl = p1
                last_cubic_ctrl = None

        elif cmd in "Aa":
            while has_number():
                _rx, _ry, _rot, _large, _sweep, x, y = [read_num() for _ in range(7)]
                if cmd == "a":
                    x += current[0]
                    y += current[1]
                end = (x, y)
                sample_line(points, current, end)
                current = end
                last_cubic_ctrl = None
                last_quad_ctrl = None

        elif cmd in "Zz":
            sample_line(points, current, start)
            current = start
            last_cubic_ctrl = None
            last_quad_ctrl = None
            cmd = ""

        else:
            raise ValueError(f"Unsupported SVG path command near token {i}: {cmd}")

    return points


def point_line_distance(point: tuple[float, float], start: tuple[float, float], end: tuple[float, float]) -> float:
    px, py = point
    sx, sy = start
    ex, ey = end
    dx = ex - sx
    dy = ey - sy
    if dx == 0.0 and dy == 0.0:
        return math.hypot(px - sx, py - sy)

    t = max(0.0, min(1.0, ((px - sx) * dx + (py - sy) * dy) / (dx * dx + dy * dy)))
    nearest = (sx + dx * t, sy + dy * t)
    return math.hypot(px - nearest[0], py - nearest[1])


def simplify_points(points: list[tuple[float, float]], tolerance: float = 1.0) -> list[tuple[float, float]]:
    if len(points) <= 2:
        return points

    start = points[0]
    end = points[-1]
    max_distance = 0.0
    split_index = 0
    for index in range(1, len(points) - 1):
        distance = point_line_distance(points[index], start, end)
        if distance > max_distance:
            max_distance = distance
            split_index = index

    if max_distance <= tolerance:
        return [start, end]

    left = simplify_points(points[: split_index + 1], tolerance)
    right = simplify_points(points[split_index:], tolerance)
    return left[:-1] + right


def outline_from_path(d: str) -> list[list[float]]:
    points = parse_path_points(d)
    simplified = simplify_points(points, 1.1)
    return [[round(x, 2), round(y, 2)] for x, y in simplified]


def extract_svg() -> tuple[dict[str, dict], dict[str, tuple[float, float]], tuple[float, float]]:
    tree = ET.parse(SVG_PATH)
    root = tree.getroot()
    width = to_float(root.attrib.get("width"))
    height = to_float(root.attrib.get("height"))

    provinces: dict[str, dict] = {}
    centers: dict[str, tuple[float, float]] = {}

    in_features = False
    in_label_points = False
    for elem in root.iter():
        tag = local_name(elem.tag)
        if tag == "g":
            in_features = elem.attrib.get("id") == "features"
            in_label_points = elem.attrib.get("id") == "label_points"
            continue

        if tag == "path" and in_features:
            province_id = elem.attrib.get("id")
            name = elem.attrib.get("name")
            d = elem.attrib.get("d")
            if province_id and name and d:
                provinces[province_id] = {
                    "id": province_id,
                    "name": name,
                    "path": d,
                    "outline": outline_from_path(d),
                    "center": None,
                    "neighbors": [],
                    "capital": None,
                    "terrain": "plain",
                    "income": 5,
                    "manpower": 5,
                }

        if tag == "circle" and in_label_points:
            province_id = elem.attrib.get("id")
            if province_id:
                centers[province_id] = (to_float(elem.attrib.get("cx")), to_float(elem.attrib.get("cy")))

    for province_id, point in centers.items():
        if province_id in provinces:
            provinces[province_id]["center"] = {"x": round(point[0], 3), "y": round(point[1], 3)}

    return provinces, centers, (width, height)


def infer_neighbors(provinces: dict[str, dict]) -> dict[tuple[str, str], dict]:
    cell = 2.0
    threshold = 1.35
    threshold_sq = threshold * threshold
    grid: dict[tuple[int, int], list[tuple[str, float, float]]] = defaultdict(list)
    matches: dict[tuple[str, str], dict] = {}

    for province_id, province in provinces.items():
        points = parse_path_points(province["path"])
        province["_sample_count"] = len(points)

        # Deduplicate very close points per province to keep matching stable.
        seen: set[tuple[int, int]] = set()
        for x, y in points:
            q = (round(x, 1), round(y, 1))
            key_seen = (int(q[0] * 10), int(q[1] * 10))
            if key_seen in seen:
                continue
            seen.add(key_seen)

            gx, gy = int(math.floor(x / cell)), int(math.floor(y / cell))
            for nx in range(gx - 1, gx + 2):
                for ny in range(gy - 1, gy + 2):
                    for other_id, ox, oy in grid.get((nx, ny), []):
                        if other_id == province_id:
                            continue
                        dx = x - ox
                        dy = y - oy
                        if dx * dx + dy * dy <= threshold_sq:
                            key = pair_key(province_id, other_id)
                            item = matches.setdefault(
                                key,
                                {"count": 0, "min_x": x, "max_x": x, "min_y": y, "max_y": y},
                            )
                            item["count"] += 1
                            item["min_x"] = min(item["min_x"], x)
                            item["max_x"] = max(item["max_x"], x)
                            item["min_y"] = min(item["min_y"], y)
                            item["max_y"] = max(item["max_y"], y)

            grid[(gx, gy)].append((province_id, x, y))

    accepted: dict[tuple[str, str], dict] = {}
    for key, item in matches.items():
        span = math.hypot(item["max_x"] - item["min_x"], item["max_y"] - item["min_y"])
        if item["count"] >= 6 and span >= 5.0:
            accepted[key] = {"shared_sample_count": item["count"], "shared_span": round(span, 3)}
    return accepted


def main() -> None:
    provinces, _centers, size = extract_svg()
    edge_debug = infer_neighbors(provinces)

    for a, b in edge_debug:
        provinces[a]["neighbors"].append(b)
        provinces[b]["neighbors"].append(a)

    for province in provinces.values():
        province["neighbors"] = sorted(province["neighbors"])
        province.pop("_sample_count", None)

    output = {
        "meta": {
            "source_svg": "fr_downloaded.svg",
            "source_kind": "SimpleMaps France SVG",
            "map_width": size[0],
            "map_height": size[1],
            "province_count": len(provinces),
            "edge_count": len(edge_debug),
            "neighbor_algorithm": {
                "name": "sampled_boundary_contact",
                "description": "SVG paths are sampled along their boundaries. Two provinces are neighbors when enough sampled boundary points from both shapes fall within a small distance threshold and the contact spans more than a tiny point touch.",
                "sample_step_px": 2.0,
                "match_distance_px": 1.35,
                "minimum_shared_sample_count": 6,
                "minimum_shared_span_px": 5.0,
            },
        },
        "provinces": {key: provinces[key] for key in sorted(provinces)},
    }

    OUT_PATH.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"wrote={OUT_PATH}")
    print(f"province_count={len(provinces)}")
    print(f"edge_count={len(edge_debug)}")
    for province_id in ["FR59", "FR75", "FR2A", "FR2B", "FR33", "FR13"]:
        if province_id in provinces:
            print(f"{province_id} {provinces[province_id]['name'].encode('ascii', 'replace').decode('ascii')}: {provinces[province_id]['neighbors']}")


if __name__ == "__main__":
    main()
