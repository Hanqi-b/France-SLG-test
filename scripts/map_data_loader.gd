extends RefCounted


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing file: " + path)
		return {}

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON: " + path)
		return {}
	return parsed


static func outline_to_polygon(outline: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for raw_point in outline:
		points.append(Vector2(float(raw_point[0]), float(raw_point[1])))
	if points.size() > 1 and points[0].distance_to(points[points.size() - 1]) < 0.01:
		points.remove_at(points.size() - 1)
	return points


static func build_province_to_region(regions: Dictionary) -> Dictionary:
	var province_to_region := {}
	for region_id in regions.keys():
		for department in regions[region_id]["departments"]:
			province_to_region[department["id"]] = region_id
	return province_to_region
