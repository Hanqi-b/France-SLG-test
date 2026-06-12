extends RefCounted

const TAX_BASE_COST_FACTOR := 18.0
const MANPOWER_VALUE_COST_FACTOR := 15.0
const POPULATION_ECONOMY_DRAG := 0.05
const URBAN_BIRTHRATE_DRAG := 0.05


static func build_initial_province_state(provinces: Dictionary, province_order: Array[String]) -> Dictionary:
	var province_state := {}
	for province_id in province_order:
		var game_values: Dictionary = provinces[province_id]["game_values"]
		var tax_base := int(game_values["tax_base"])
		var manpower_value := int(game_values["population_value"])
		province_state[province_id] = {
			"base_tax_base": tax_base,
			"base_manpower_value": manpower_value,
			"tax_base_added": 0,
			"manpower_value_added": 0,
			"tax_base": tax_base,
			"manpower_value": manpower_value,
			"income": calculate_province_income(tax_base, manpower_value),
			"manpower_growth": calculate_manpower_growth(tax_base, manpower_value),
		}
	return province_state


static func calculate_province_income(tax_base: int, manpower_value: int) -> int:
	var base_income := log(float(tax_base) + 1.0) * 9.0 + log(float(manpower_value) + 1.0) * 3.0
	var population_drag := 1.0 + log(float(manpower_value) + 1.0) * POPULATION_ECONOMY_DRAG
	return max(1, int(round(base_income / population_drag)))


static func calculate_manpower_growth(tax_base: int, manpower_value: int) -> int:
	var base_growth := log(float(manpower_value) + 1.0) * 3.5
	var urban_drag := 1.0 + log(float(tax_base) + 1.0) * URBAN_BIRTHRATE_DRAG
	return max(1, int(round(base_growth / urban_drag)))


static func tax_base_cost(province_state: Dictionary, province_id: String) -> int:
	var state: Dictionary = province_state[province_id]
	var tax_base := int(state["tax_base"])
	var manpower_value := int(state["manpower_value"])
	var added := int(state["tax_base_added"])
	var manpower_drag := 1.0 + log(float(manpower_value) + 1.0) * POPULATION_ECONOMY_DRAG
	var base_scale := log(float(tax_base + manpower_value) + 2.0)
	var added_scale := log(float(added) + 2.0)
	return max(10, int(round((40.0 + base_scale * added_scale * TAX_BASE_COST_FACTOR) * manpower_drag)))


static func manpower_value_cost(province_state: Dictionary, province_id: String) -> int:
	var state: Dictionary = province_state[province_id]
	var tax_base := int(state["tax_base"])
	var manpower_value := int(state["manpower_value"])
	var added := int(state["manpower_value_added"])
	var urban_drag := 1.0 + log(float(tax_base) + 1.0) * URBAN_BIRTHRATE_DRAG
	var base_scale := log(float(manpower_value) + 2.0)
	var added_scale := log(float(added) + 2.0)
	return max(10, int(round((30.0 + base_scale * added_scale * MANPOWER_VALUE_COST_FACTOR) * urban_drag)))


static func recalculate_province_values(province_state: Dictionary, province_id: String) -> void:
	var state: Dictionary = province_state[province_id]
	state["income"] = calculate_province_income(
		int(state["tax_base"]),
		int(state["manpower_value"])
	)
	state["manpower_growth"] = calculate_manpower_growth(
		int(state["tax_base"]),
		int(state["manpower_value"])
	)


static func region_income(regions: Dictionary, provinces: Dictionary, province_state: Dictionary, region_id: String) -> int:
	return int(region_totals(regions, provinces, province_state, region_id)["income"])


static func region_manpower_growth(regions: Dictionary, provinces: Dictionary, province_state: Dictionary, region_id: String) -> int:
	return int(region_totals(regions, provinces, province_state, region_id)["manpower_growth"])


static func region_totals(regions: Dictionary, provinces: Dictionary, province_state: Dictionary, region_id: String) -> Dictionary:
	var result := {
		"province_count": 0,
		"tax_base": 0,
		"manpower_value": 0,
		"income": 0,
		"manpower_growth": 0,
		"population": 0,
		"gdp": 0.0,
	}

	if not regions.has(region_id):
		return result

	for department in regions[region_id]["departments"]:
		var province_id: String = department["id"]
		var province: Dictionary = provinces[province_id]
		var state: Dictionary = province_state[province_id]
		var stats: Dictionary = province["stats"]["2022"]
		result["province_count"] += 1
		result["tax_base"] += int(state["tax_base"])
		result["manpower_value"] += int(state["manpower_value"])
		result["income"] += int(state["income"])
		result["manpower_growth"] += int(state["manpower_growth"])
		result["population"] += int(stats["population"]["value"])
		result["gdp"] += float(stats["economy"]["gdp_current_market_prices"]["value"])

	return result
