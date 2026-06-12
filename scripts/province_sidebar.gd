extends PanelContainer

const DisplayUtils = preload("res://scripts/display_utils.gd")

signal economic_develop_requested
signal manpower_develop_requested

var selection_title: Label
var selection_body: Label
var status_label: Label
var economic_develop_button: Button
var manpower_develop_button: Button


func build() -> void:
	name = "ProvinceSidebar"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "省份信息"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	selection_title = Label.new()
	selection_title.add_theme_font_size_override("font_size", 18)
	box.add_child(selection_title)

	selection_body = Label.new()
	selection_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(selection_body)

	economic_develop_button = Button.new()
	economic_develop_button.text = "发展经济"
	economic_develop_button.pressed.connect(func() -> void: economic_develop_requested.emit())
	box.add_child(economic_develop_button)

	manpower_develop_button = Button.new()
	manpower_develop_button.text = "发展人力"
	manpower_develop_button.pressed.connect(func() -> void: manpower_develop_requested.emit())
	box.add_child(manpower_develop_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)


func show_initial() -> void:
	selection_title.text = "省份"
	selection_body.text = "未选择"
	status_label.text = ""
	economic_develop_button.disabled = true
	manpower_develop_button.disabled = true


func show_province(
	province_id: String,
	province: Dictionary,
	region_name: String,
	state: Dictionary,
	stats: Dictionary,
	economy: Dictionary,
	owned: bool,
	economic_cost: int,
	manpower_cost: int
) -> void:
	selection_title.text = "%s (%s)" % [province["name"], province_id]
	selection_body.text = "\n".join([
		"所属大区: %s" % region_name,
		"控制状态: %s" % ("己方" if owned else "其它政治实体"),
		"经济发展: %d" % int(state["economic_development"]),
		"人力发展: %d" % int(state["manpower_development"]),
		"当前收入: %d / 回合" % int(state["income"]),
		"人力增长: %d / 回合" % int(state["manpower_growth"]),
		"发展经济花费: %d 金钱" % economic_cost,
		"发展人力花费: %d 人力" % manpower_cost,
		"税基: %d" % int(state["tax_base"]),
		"人力值: %d" % int(state["manpower_value"]),
		"真实人口: %s" % DisplayUtils.format_int(stats["population"]["value"]),
		"GDP: %s million EUR" % DisplayUtils.format_float(economy["gdp_current_market_prices"]["value"], 1),
		"人均 GDP: %s EUR" % DisplayUtils.format_float(economy["gdp_per_capita"]["value"], 2),
		"邻接省份: %d" % province["neighbors"].size(),
	])
	economic_develop_button.text = "发展经济：%d" % economic_cost
	manpower_develop_button.text = "发展人力：%d" % manpower_cost
	economic_develop_button.disabled = not owned
	manpower_develop_button.disabled = not owned
	status_label.text = "" if owned else "非己方省份只能查看"


func set_status(text: String) -> void:
	status_label.text = text
