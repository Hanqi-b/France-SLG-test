extends RefCounted

const DEVELOPMENT_INCOME_FACTOR := 0.28
const MANPOWER_GROWTH_FACTOR := 0.30
const ECONOMIC_DEVELOPMENT_COST_FACTOR := 18.0
const MANPOWER_DEVELOPMENT_COST_FACTOR := 15.0
const POPULATION_ECONOMY_DRAG := 0.05
const URBAN_BIRTHRATE_DRAG := 0.05


static func build_initial_province_state(provinces: Dictionary, province_order: Array[String]) -> Dictionary:
	var province_state := {}
	for province_id in province_order:
		var game_values: Dictionary = provinces[province_id]["game_values"]
		var tax_base := int(game_values["tax_base"])
		var manpower_value := int(game_values["population_value"])
		var economic_development := 1
		var manpower_development := 1
		province_state[province_id] = {
			"economic_development": economic_development,
			"manpower_development": manpower_development,
			"tax_base": tax_base,
			"manpower_value": manpower_value,
			"income": calculate_province_income(tax_base, manpower_value, economic_development, manpower_development),
			"manpower_growth": calculate_manpower_growth(manpower_value, manpower_development, economic_development),
		}
	return province_state


static func calculate_province_income(tax_base: int, manpower_value: int, economic_development: int, manpower_development: int) -> int:
	var base_income := log(float(tax_base) + 1.0) * 9.0 + log(float(manpower_value) + 1.0) * 3.0
	var development_multiplier := 1.0 + log(float(economic_development) + 1.0) * DEVELOPMENT_INCOME_FACTOR
	var population_drag := 1.0 + log(float(manpower_development) + 1.0) * POPULATION_ECONOMY_DRAG
	return max(1, int(round(base_income * development_multiplier / population_drag)))


static func calculate_manpower_growth(manpower_value: int, manpower_development: int, economic_development: int) -> int:
	var base_growth := log(float(manpower_value) + 1.0) * 3.5
	var development_multiplier := 1.0 + log(float(manpower_development) + 1.0) * MANPOWER_GROWTH_FACTOR
	var urban_drag := 1.0 + log(float(economic_development) + 1.0) * URBAN_BIRTHRATE_DRAG
	return max(1, int(round(base_growth * development_multiplier / urban_drag)))


static func economic_development_cost(province_state: Dictionary, province_id: String) -> int:
	var state: Dictionary = province_state[province_id]
	var tax_base := int(state["tax_base"])
	var manpower_value := int(state["manpower_value"])
	var development := int(state["economic_development"])
	var manpower_drag := 1.0 + log(float(state["manpower_development"]) + 1.0) * POPULATION_ECONOMY_DRAG
	var base_scale := log(float(tax_base + manpower_value) + 2.0)
	var development_scale := log(float(development) + 2.0)
	return max(10, int(round((40.0 + base_scale * development_scale * ECONOMIC_DEVELOPMENT_COST_FACTOR) * manpower_drag)))


static func manpower_development_cost(province_state: Dictionary, province_id: String) -> int:
	var state: Dictionary = province_state[province_id]
	var manpower_value := int(state["manpower_value"])
	var development := int(state["manpower_development"])
	var urban_drag := 1.0 + log(float(state["economic_development"]) + 1.0) * URBAN_BIRTHRATE_DRAG
	var base_scale := log(float(manpower_value) + 2.0)
	var development_scale := log(float(development) + 2.0)
	return max(10, int(round((30.0 + base_scale * development_scale * MANPOWER_DEVELOPMENT_COST_FACTOR) * urban_drag)))


static func recalculate_province_values(province_state: Dictionary, province_id: String) -> void:
	var state: Dictionary = province_state[province_id]
	state["income"] = calculate_province_income(
		int(state["tax_base"]),
		int(state["manpower_value"]),
		int(state["economic_development"]),
		int(state["manpower_development"])
	)
	state["manpower_growth"] = calculate_manpower_growth(
		int(state["manpower_value"]),
		int(state["manpower_development"]),
		int(state["economic_development"])
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
		"economic_development": 0,
		"manpower_development": 0,
		"average_economic_development": 0.0,
		"average_manpower_development": 0.0,
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
		result["economic_development"] += int(state["economic_development"])
		result["manpower_development"] += int(state["manpower_development"])
		result["income"] += int(state["income"])
		result["manpower_growth"] += int(state["manpower_growth"])
		result["population"] += int(stats["population"]["value"])
		result["gdp"] += float(stats["economy"]["gdp_current_market_prices"]["value"])

	if int(result["province_count"]) > 0:
		result["average_economic_development"] = float(result["economic_development"]) / float(result["province_count"])
		result["average_manpower_development"] = float(result["manpower_development"]) / float(result["province_count"])

	return result
