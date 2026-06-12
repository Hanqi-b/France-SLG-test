extends PanelContainer

var selection_title: Label
var selection_body: Label
var status_label: Label
var tax_base_button: Button
var manpower_value_button: Button


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

	tax_base_button = Button.new()
	tax_base_button.text = "增加税基"
	tax_base_button.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(tax_base_button)

	manpower_value_button = Button.new()
	manpower_value_button.text = "增加人力值"
	manpower_value_button.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(manpower_value_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)


func show_initial() -> void:
	selection_title.text = "省份"
	selection_body.text = "未选择"
	status_label.text = ""
	tax_base_button.disabled = true
	manpower_value_button.disabled = true


func show_province(
	province_id: String,
	province: Dictionary,
	region_name: String,
	state: Dictionary,
	_stats: Dictionary,
	_economy: Dictionary,
	owned: bool,
	tax_base_cost: int,
	manpower_value_cost: int
) -> void:
	selection_title.text = "%s (%s)" % [province["name"], province_id]
	selection_body.text = "\n".join([
		"所属大区: %s" % region_name,
		"控制状态: %s" % ("己方" if owned else "其它政治实体"),
		"税基: %d = %d + %d" % [int(state["tax_base"]), int(state["base_tax_base"]), int(state["tax_base_added"])],
		"人力值: %d = %d + %d" % [int(state["manpower_value"]), int(state["base_manpower_value"]), int(state["manpower_value_added"])],
		"当前收入: %d / 回合" % int(state["income"]),
		"人力增长: %d / 回合" % int(state["manpower_growth"]),
		"增加税基花费: %d 金钱" % tax_base_cost,
		"增加人力值花费: %d 人力" % manpower_value_cost,
	])
	tax_base_button.text = "增加税基：%d" % tax_base_cost
	manpower_value_button.text = "增加人力值：%d" % manpower_value_cost
	tax_base_button.disabled = not owned
	manpower_value_button.disabled = not owned
	status_label.text = "" if owned else "非己方省份只能查看"


func set_status(text: String) -> void:
	status_label.text = text
