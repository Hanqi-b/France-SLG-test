extends PanelContainer

const DisplayUtils = preload("res://scripts/display_utils.gd")

signal end_turn_requested

var player_title: Label
var turn_label: Label
var treasury_label: Label
var manpower_label: Label
var total_income_label: Label
var total_manpower_growth_label: Label
var player_region_body: Label
var end_turn_button: Button


func build() -> void:
	name = "PlayerRegionPanel"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	player_title = Label.new()
	player_title.text = "你的大区"
	player_title.add_theme_font_size_override("font_size", 22)
	box.add_child(player_title)

	turn_label = Label.new()
	box.add_child(turn_label)

	treasury_label = Label.new()
	box.add_child(treasury_label)

	manpower_label = Label.new()
	box.add_child(manpower_label)

	total_income_label = Label.new()
	box.add_child(total_income_label)

	total_manpower_growth_label = Label.new()
	box.add_child(total_manpower_growth_label)

	player_region_body = Label.new()
	player_region_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(player_region_body)

	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	box.add_child(end_turn_button)


func show_empty() -> void:
	player_title.text = "你的大区"
	turn_label.text = "回合: -"
	treasury_label.text = "国库: -"
	manpower_label.text = "人力: -"
	total_income_label.text = "总收入: -"
	total_manpower_growth_label.text = "人力增长: -"
	player_region_body.text = ""
	end_turn_button.disabled = true


func show_region(region_name: String, turn: int, treasury: int, manpower: int, summary: Dictionary) -> void:
	player_title.text = region_name
	turn_label.text = "回合: %d" % turn
	treasury_label.text = "国库: %d" % treasury
	manpower_label.text = "人力: %d" % manpower
	total_income_label.text = "总收入: %d / 回合" % int(summary["income"])
	total_manpower_growth_label.text = "人力增长: %d / 回合" % int(summary["manpower_growth"])
	player_region_body.text = "\n".join([
		"省份数: %d" % int(summary["province_count"]),
		"平均经济发展: %s" % DisplayUtils.format_float(summary["average_economic_development"], 2),
		"平均人力发展: %s" % DisplayUtils.format_float(summary["average_manpower_development"], 2),
		"总税基: %d" % int(summary["tax_base"]),
		"总人力值: %d" % int(summary["manpower_value"]),
		"真实总人口: %s" % DisplayUtils.format_int(summary["population"]),
		"GDP 合计: %s million EUR" % DisplayUtils.format_float(summary["gdp"], 1),
	])
	end_turn_button.disabled = false
