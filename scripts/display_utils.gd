extends RefCounted


static func region_name(regions: Dictionary, region_id: String) -> String:
	if region_id == "" or not regions.has(region_id):
		return "Unknown"
	var raw_name: String = str(regions[region_id].get("name", ""))
	if raw_name.find("茅") != -1 or raw_name.find("么") != -1 or raw_name.find("猫") != -1 or raw_name.find("脦") != -1:
		return title_from_id(region_id)
	return raw_name


static func title_from_id(region_id: String) -> String:
	var words := PackedStringArray()
	for part in region_id.split("_"):
		if part == "de" or part == "du" or part == "d":
			words.append(part)
		else:
			words.append(part.capitalize())
	return " ".join(words)


static func point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var count := polygon.size()
	var j := count - 1

	for i in range(count):
		var pi := polygon[i]
		var pj := polygon[j]
		if (pi.y > point.y) != (pj.y > point.y):
			var x_intersect := (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
			if point.x < x_intersect:
				inside = not inside
		j = i

	return inside


static func format_int(value) -> String:
	var text := str(int(value))
	var output := ""
	var count := 0
	for index in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			output = "," + output
		output = text.substr(index, 1) + output
		count += 1
	return output


static func format_float(value, decimals: int) -> String:
	var format := "%." + str(decimals) + "f"
	return format % float(value)
