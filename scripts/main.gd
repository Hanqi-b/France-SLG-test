extends Node2D

const PROVINCES_PATH := "res://data/provinces.json"
const REGIONS_PATH := "res://data/regions_post_2016.json"
const MAP_SVG_PATH := "res://data/fr_regions_colored.svg"

const SIDEBAR_DEFAULT_WIDTH := 340.0
const SIDEBAR_MIN_WIDTH := 260.0
const SIDEBAR_MAX_WIDTH := 520.0
const SIDEBAR_HANDLE_WIDTH := 8.0
const RIGHT_PANEL_WIDTH := 320.0
const MAP_PADDING := 24.0
const MIN_ZOOM := 1.0
const MAX_ZOOM := 7.0
const PAN_LIMIT_MARGIN := 80.0
const DRAG_THRESHOLD := 4.0

const STARTING_TREASURY := 500
const STARTING_MANPOWER := 120
const DEVELOPMENT_INCOME_FACTOR := 0.28
const MANPOWER_GROWTH_FACTOR := 0.30
const ECONOMIC_DEVELOPMENT_COST_FACTOR := 18.0
const MANPOWER_DEVELOPMENT_COST_FACTOR := 15.0
const POPULATION_ECONOMY_DRAG := 0.05
const URBAN_BIRTHRATE_DRAG := 0.05

var provinces: Dictionary = {}
var regions: Dictionary = {}
var province_order: Array[String] = []
var province_polygons: Dictionary = {}
var province_to_region: Dictionary = {}
var province_state: Dictionary = {}
var selected_province_id := ""
var selected_region_id := ""
var player_region_id := ""
var game_started := false

var turn := 1
var treasury := STARTING_TREASURY
var manpower := STARTING_MANPOWER
var last_turn_income := 0
var last_turn_manpower_growth := 0

var map_width := 1000.0
var map_height := 960.0
var base_map_scale := 1.0
var zoom := 1.0
var map_scale := 1.0
var map_offset := Vector2.ZERO
var map_texture: Texture2D

var sidebar_width := SIDEBAR_DEFAULT_WIDTH
var sidebar_panel: PanelContainer
var sidebar_handle: Control
var right_panel: PanelContainer
var start_overlay: Control

var selection_title: Label
var selection_body: Label
var local_region_title: Label
var local_region_body: Label
var status_label: Label
var economic_develop_button: Button
var manpower_develop_button: Button

var player_title: Label
var turn_label: Label
var treasury_label: Label
var manpower_label: Label
var total_income_label: Label
var total_manpower_growth_label: Label
var player_region_body: Label
var end_turn_button: Button

var is_panning := false
var is_resizing_sidebar := false
var pan_button := 0
var pointer_down_position := Vector2.ZERO
var last_pointer_position := Vector2.ZERO
var drag_moved := false


func _ready() -> void:
	_load_data()
	_initialize_runtime_state()
	_load_map_texture()
	_create_ui()
	get_viewport().size_changed.connect(_layout_view)
	_layout_view()
	_show_initial_state()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.08, 0.09, 0.10), true)

	if map_texture != null:
		draw_texture_rect(map_texture, Rect2(map_offset, Vector2(map_width, map_height) * map_scale), false)

	for province_id in province_order:
		var screen_points := _screen_polygon(province_id)
		screen_points.append(screen_points[0])
		var width := 0.7
		var color := Color(0.06, 0.08, 0.10, 0.55)
		if province_to_region.get(province_id, "") == player_region_id:
			width = 1.35
			color = Color(0.95, 1.0, 0.78, 0.75)
		if province_id == selected_province_id:
			width = 3.0
			color = Color(1.0, 1.0, 1.0, 0.98)
		draw_polyline(screen_points, color, width)

	if selected_province_id != "":
		var center := _province_center_screen(selected_province_id)
		draw_circle(center, 5.0, Color.WHITE)
		draw_arc(center, 11.0, 0.0, TAU, 48, Color(0.04, 0.05, 0.06), 2.0)


func _input(event: InputEvent) -> void:
	if is_resizing_sidebar:
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			sidebar_width = clamp(motion.position.x, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH)
			_layout_view(false)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and not event.pressed:
			is_resizing_sidebar = false
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not _is_in_map_view(event.position):
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.14)
		get_viewport().set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / 1.14)
		get_viewport().set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			is_panning = true
			pan_button = event.button_index
			pointer_down_position = event.position
			last_pointer_position = event.position
			drag_moved = false
		else:
			if is_panning and pan_button == event.button_index:
				is_panning = false
				if event.button_index == MOUSE_BUTTON_LEFT and not drag_moved:
					_select_at(event.position)
		get_viewport().set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_region_at(event.position)
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_panning:
		return

	if event.position.distance_to(pointer_down_position) > DRAG_THRESHOLD:
		drag_moved = true

	if drag_moved:
		map_offset += event.position - last_pointer_position
		_clamp_map_offset()
		queue_redraw()

	last_pointer_position = event.position
	get_viewport().set_input_as_handled()


func _load_data() -> void:
	var province_json := _read_json(PROVINCES_PATH)
	var region_json := _read_json(REGIONS_PATH)

	if province_json.is_empty() or region_json.is_empty():
		return

	provinces = province_json["provinces"]
	regions = region_json["regions"]
	map_width = float(province_json["meta"].get("map_width", 1000.0))
	map_height = float(province_json["meta"].get("map_height", 960.0))

	province_order.clear()
	for province_id in provinces.keys():
		province_order.append(province_id)
	province_order.sort()

	for province_id in province_order:
		var points := PackedVector2Array()
		for raw_point in provinces[province_id]["outline"]:
			points.append(Vector2(float(raw_point[0]), float(raw_point[1])))
		if points.size() > 1 and points[0].distance_to(points[points.size() - 1]) < 0.01:
			points.remove_at(points.size() - 1)
		province_polygons[province_id] = points

	for region_id in regions.keys():
		for department in regions[region_id]["departments"]:
			province_to_region[department["id"]] = region_id


func _initialize_runtime_state() -> void:
	province_state.clear()
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
			"income": _calculate_province_income(tax_base, manpower_value, economic_development, manpower_development),
			"manpower_growth": _calculate_manpower_growth(manpower_value, manpower_development, economic_development),
		}


func _calculate_province_income(tax_base: int, manpower_value: int, economic_development: int, manpower_development: int) -> int:
	var base_income := log(float(tax_base) + 1.0) * 9.0 + log(float(manpower_value) + 1.0) * 3.0
	var development_multiplier := 1.0 + log(float(economic_development) + 1.0) * DEVELOPMENT_INCOME_FACTOR
	var population_drag := 1.0 + log(float(manpower_development) + 1.0) * POPULATION_ECONOMY_DRAG
	return max(1, int(round(base_income * development_multiplier / population_drag)))


func _calculate_manpower_growth(manpower_value: int, manpower_development: int, economic_development: int) -> int:
	var base_growth := log(float(manpower_value) + 1.0) * 3.5
	var development_multiplier := 1.0 + log(float(manpower_development) + 1.0) * MANPOWER_GROWTH_FACTOR
	var urban_drag := 1.0 + log(float(economic_development) + 1.0) * URBAN_BIRTHRATE_DRAG
	return max(1, int(round(base_growth * development_multiplier / urban_drag)))


func _calculate_economic_development_cost(province_id: String) -> int:
	var state: Dictionary = province_state[province_id]
	var tax_base := int(state["tax_base"])
	var manpower_value := int(state["manpower_value"])
	var development := int(state["economic_development"])
	var manpower_drag := 1.0 + log(float(state["manpower_development"]) + 1.0) * POPULATION_ECONOMY_DRAG
	var base_scale := log(float(tax_base + manpower_value) + 2.0)
	var development_scale := log(float(development) + 2.0)
	return max(10, int(round((40.0 + base_scale * development_scale * ECONOMIC_DEVELOPMENT_COST_FACTOR) * manpower_drag)))


func _calculate_manpower_development_cost(province_id: String) -> int:
	var state: Dictionary = province_state[province_id]
	var manpower_value := int(state["manpower_value"])
	var development := int(state["manpower_development"])
	var urban_drag := 1.0 + log(float(state["economic_development"]) + 1.0) * URBAN_BIRTHRATE_DRAG
	var base_scale := log(float(manpower_value) + 2.0)
	var development_scale := log(float(development) + 2.0)
	return max(10, int(round((30.0 + base_scale * development_scale * MANPOWER_DEVELOPMENT_COST_FACTOR) * urban_drag)))


func _recalculate_province_values(province_id: String) -> void:
	var state: Dictionary = province_state[province_id]
	state["income"] = _calculate_province_income(
		int(state["tax_base"]),
		int(state["manpower_value"]),
		int(state["economic_development"]),
		int(state["manpower_development"])
	)
	state["manpower_growth"] = _calculate_manpower_growth(
		int(state["manpower_value"]),
		int(state["manpower_development"]),
		int(state["economic_development"])
	)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing file: " + path)
		return {}

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON: " + path)
		return {}
	return parsed


func _load_map_texture() -> void:
	var bytes := FileAccess.get_file_as_bytes(MAP_SVG_PATH)
	if bytes.is_empty():
		push_error("Missing SVG map: " + MAP_SVG_PATH)
		return

	var image := Image.new()
	var error := image.load_svg_from_buffer(bytes)
	if error != OK:
		push_error("Could not load SVG map: " + MAP_SVG_PATH)
		return

	map_texture = ImageTexture.create_from_image(image)


func _create_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	_create_left_sidebar(ui)
	_create_right_panel(ui)
	_create_start_overlay(ui)


func _create_left_sidebar(ui: CanvasLayer) -> void:
	sidebar_panel = PanelContainer.new()
	sidebar_panel.name = "ProvinceSidebar"
	ui.add_child(sidebar_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	sidebar_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "省份与大区"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	selection_title = Label.new()
	selection_title.add_theme_font_size_override("font_size", 18)
	box.add_child(selection_title)

	selection_body = Label.new()
	selection_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(selection_body)

	var separator := HSeparator.new()
	box.add_child(separator)

	local_region_title = Label.new()
	local_region_title.add_theme_font_size_override("font_size", 18)
	box.add_child(local_region_title)

	local_region_body = Label.new()
	local_region_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(local_region_body)

	economic_develop_button = Button.new()
	economic_develop_button.text = "发展经济"
	economic_develop_button.pressed.connect(_on_economic_develop_pressed)
	box.add_child(economic_develop_button)

	manpower_develop_button = Button.new()
	manpower_develop_button.text = "发展人力"
	manpower_develop_button.pressed.connect(_on_manpower_develop_pressed)
	box.add_child(manpower_develop_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	sidebar_handle = Control.new()
	sidebar_handle.name = "SidebarResizeHandle"
	sidebar_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	sidebar_handle.gui_input.connect(_on_sidebar_handle_input)
	ui.add_child(sidebar_handle)


func _create_right_panel(ui: CanvasLayer) -> void:
	right_panel = PanelContainer.new()
	right_panel.name = "PlayerRegionPanel"
	ui.add_child(right_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	right_panel.add_child(margin)

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
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	box.add_child(end_turn_button)


func _create_start_overlay(ui: CanvasLayer) -> void:
	start_overlay = Control.new()
	start_overlay.name = "RegionSelectOverlay"
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(start_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 520)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_top = -260
	panel.offset_right = 280
	panel.offset_bottom = 260
	start_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "选择开局大区"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)

	var region_ids := regions.keys()
	region_ids.sort()
	for region_id in region_ids:
		var button := Button.new()
		button.text = _region_name(region_id)
		button.custom_minimum_size = Vector2(240, 36)
		button.pressed.connect(_on_region_chosen.bind(region_id))
		grid.add_child(button)


func _on_sidebar_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			is_resizing_sidebar = true
			get_viewport().set_input_as_handled()


func _layout_view(reset_pan := true) -> void:
	var viewport_size := get_viewport_rect().size

	sidebar_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sidebar_panel.offset_left = 0.0
	sidebar_panel.offset_top = 0.0
	sidebar_panel.offset_right = sidebar_width
	sidebar_panel.offset_bottom = viewport_size.y

	sidebar_handle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sidebar_handle.offset_left = sidebar_width - SIDEBAR_HANDLE_WIDTH * 0.5
	sidebar_handle.offset_top = 0.0
	sidebar_handle.offset_right = sidebar_width + SIDEBAR_HANDLE_WIDTH * 0.5
	sidebar_handle.offset_bottom = viewport_size.y

	right_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_panel.offset_left = -RIGHT_PANEL_WIDTH
	right_panel.offset_top = 0.0
	right_panel.offset_right = 0.0
	right_panel.offset_bottom = viewport_size.y

	var view := _map_view_rect()
	base_map_scale = min((view.size.x - MAP_PADDING * 2.0) / map_width, (view.size.y - MAP_PADDING * 2.0) / map_height)
	base_map_scale = max(0.1, base_map_scale)
	map_scale = base_map_scale * zoom

	if reset_pan:
		map_offset = view.position + (view.size - Vector2(map_width, map_height) * map_scale) * 0.5
	else:
		_clamp_map_offset()

	queue_redraw()


func _map_view_rect() -> Rect2:
	var size := get_viewport_rect().size
	var width: float = max(1.0, size.x - sidebar_width - RIGHT_PANEL_WIDTH)
	return Rect2(Vector2(sidebar_width, 0.0), Vector2(width, size.y))


func _is_in_map_view(position: Vector2) -> bool:
	return _map_view_rect().has_point(position)


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var old_scale := map_scale
	var old_zoom := zoom
	zoom = clamp(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(zoom, old_zoom):
		return

	map_scale = base_map_scale * zoom
	var map_point := (screen_position - map_offset) / old_scale
	map_offset = screen_position - map_point * map_scale
	_clamp_map_offset()
	queue_redraw()


func _clamp_map_offset() -> void:
	var view := _map_view_rect().grow(-MAP_PADDING)
	var map_size := Vector2(map_width, map_height) * map_scale

	if map_size.x <= view.size.x:
		map_offset.x = view.position.x + (view.size.x - map_size.x) * 0.5
	else:
		map_offset.x = clamp(map_offset.x, view.end.x - map_size.x - PAN_LIMIT_MARGIN, view.position.x + PAN_LIMIT_MARGIN)

	if map_size.y <= view.size.y:
		map_offset.y = view.position.y + (view.size.y - map_size.y) * 0.5
	else:
		map_offset.y = clamp(map_offset.y, view.end.y - map_size.y - PAN_LIMIT_MARGIN, view.position.y + PAN_LIMIT_MARGIN)


func _on_region_chosen(region_id: String) -> void:
	player_region_id = region_id
	selected_region_id = region_id
	game_started = true
	start_overlay.visible = false
	_refresh_player_panel()
	_show_region(region_id)
	queue_redraw()


func _show_initial_state() -> void:
	selection_title.text = "省份"
	selection_body.text = "未选择"
	local_region_title.text = "大区"
	local_region_body.text = "未选择"
	status_label.text = ""
	economic_develop_button.disabled = true
	manpower_develop_button.disabled = true
	_refresh_player_panel()


func _select_at(screen_position: Vector2) -> void:
	var province_id := _province_at(_screen_to_map(screen_position))
	if province_id == "":
		return

	selected_province_id = province_id
	_show_province(province_id)
	queue_redraw()


func _show_region_at(screen_position: Vector2) -> void:
	var province_id := _province_at(_screen_to_map(screen_position))
	if province_id == "":
		return

	var region_id: String = province_to_region.get(province_id, "")
	if region_id != "":
		_show_region(region_id)


func _on_economic_develop_pressed() -> void:
	if not _selected_province_is_owned():
		status_label.text = "只能发展自己大区的省份"
		return

	var cost := _calculate_economic_development_cost(selected_province_id)
	if treasury < cost:
		status_label.text = "国库不足：需要 %d" % cost
		return

	var state: Dictionary = province_state[selected_province_id]
	treasury -= cost
	state["economic_development"] = int(state["economic_development"]) + 1
	_recalculate_province_values(selected_province_id)
	_show_province(selected_province_id)
	_refresh_player_panel()
	status_label.text = "%s 经济发展提升到 %d" % [provinces[selected_province_id]["name"], int(state["economic_development"])]


func _on_manpower_develop_pressed() -> void:
	if not _selected_province_is_owned():
		status_label.text = "只能发展自己大区的省份"
		return

	var cost := _calculate_manpower_development_cost(selected_province_id)
	if manpower < cost:
		status_label.text = "人力不足：需要 %d" % cost
		return

	var state: Dictionary = province_state[selected_province_id]
	manpower -= cost
	state["manpower_development"] = int(state["manpower_development"]) + 1
	_recalculate_province_values(selected_province_id)
	_show_province(selected_province_id)
	_refresh_player_panel()
	status_label.text = "%s 人力发展提升到 %d" % [provinces[selected_province_id]["name"], int(state["manpower_development"])]


func _on_end_turn_pressed() -> void:
	if not game_started:
		return

	var income := _region_income(player_region_id)
	var manpower_growth := _region_manpower_growth(player_region_id)
	last_turn_income = income
	last_turn_manpower_growth = manpower_growth
	treasury += income
	manpower += manpower_growth
	turn += 1
	_refresh_player_panel()

	if selected_province_id != "":
		_show_province(selected_province_id)
	if selected_region_id != "":
		_show_region(selected_region_id)

	status_label.text = "本回合收入 +%d，人力 +%d" % [income, manpower_growth]


func _show_province(province_id: String) -> void:
	var province: Dictionary = provinces[province_id]
	var stats: Dictionary = province["stats"]["2022"]
	var economy: Dictionary = stats["economy"]
	var state: Dictionary = province_state[province_id]
	var region_id: String = province_to_region.get(province_id, "")
	var owned := region_id == player_region_id
	var economic_cost := _calculate_economic_development_cost(province_id)
	var manpower_cost := _calculate_manpower_development_cost(province_id)

	selection_title.text = "%s (%s)" % [province["name"], province_id]
	selection_body.text = "\n".join([
		"所属大区: %s" % _region_name(region_id),
		"控制状态: %s" % ("己方" if owned else "其它政治实体"),
		"经济发展: %d" % int(state["economic_development"]),
		"人力发展: %d" % int(state["manpower_development"]),
		"当前收入: %d / 回合" % int(state["income"]),
		"人力增长: %d / 回合" % int(state["manpower_growth"]),
		"发展经济花费: %d 金钱" % economic_cost,
		"发展人力花费: %d 人力" % manpower_cost,
		"税基: %d" % int(state["tax_base"]),
		"人力值: %d" % int(state["manpower_value"]),
		"真实人口: %s" % _format_int(stats["population"]["value"]),
		"GDP: %s million EUR" % _format_float(economy["gdp_current_market_prices"]["value"], 1),
		"人均 GDP: %s EUR" % _format_float(economy["gdp_per_capita"]["value"], 2),
		"邻接省份: %d" % province["neighbors"].size(),
	])
	economic_develop_button.text = "发展经济：%d" % economic_cost
	manpower_develop_button.text = "发展人力：%d" % manpower_cost
	economic_develop_button.disabled = not owned or treasury < economic_cost
	manpower_develop_button.disabled = not owned or manpower < manpower_cost
	status_label.text = "" if owned else "非己方省份只能查看"
	_show_region(region_id)


func _show_region(region_id: String) -> void:
	selected_region_id = region_id
	var summary := _region_totals(region_id)
	local_region_title.text = _region_name(region_id)
	local_region_body.text = "\n".join([
		"政治实体: %s" % ("己方" if region_id == player_region_id else "其它"),
		"省份数: %d" % int(summary["province_count"]),
		"总收入: %d / 回合" % int(summary["income"]),
		"总人力增长: %d / 回合" % int(summary["manpower_growth"]),
		"平均经济发展: %s" % _format_float(summary["average_economic_development"], 2),
		"平均人力发展: %s" % _format_float(summary["average_manpower_development"], 2),
		"总税基: %d" % int(summary["tax_base"]),
		"总人力值: %d" % int(summary["manpower_value"]),
		"真实总人口: %s" % _format_int(summary["population"]),
	])


func _refresh_player_panel() -> void:
	if player_title == null:
		return

	if not game_started:
		player_title.text = "你的大区"
		turn_label.text = "回合: -"
		treasury_label.text = "国库: -"
		manpower_label.text = "人力: -"
		total_income_label.text = "总收入: -"
		total_manpower_growth_label.text = "人力增长: -"
		player_region_body.text = ""
		end_turn_button.disabled = true
		return

	var summary := _region_totals(player_region_id)
	player_title.text = _region_name(player_region_id)
	turn_label.text = "回合: %d" % turn
	treasury_label.text = "国库: %d" % treasury
	manpower_label.text = "人力: %d" % manpower
	total_income_label.text = "总收入: %d / 回合" % int(summary["income"])
	total_manpower_growth_label.text = "人力增长: %d / 回合" % int(summary["manpower_growth"])
	player_region_body.text = "\n".join([
		"省份数: %d" % int(summary["province_count"]),
		"平均经济发展: %s" % _format_float(summary["average_economic_development"], 2),
		"平均人力发展: %s" % _format_float(summary["average_manpower_development"], 2),
		"总税基: %d" % int(summary["tax_base"]),
		"总人力值: %d" % int(summary["manpower_value"]),
		"真实总人口: %s" % _format_int(summary["population"]),
		"GDP 合计: %s million EUR" % _format_float(summary["gdp"], 1),
	])
	end_turn_button.disabled = false


func _selected_province_is_owned() -> bool:
	if selected_province_id == "":
		return false
	return province_to_region.get(selected_province_id, "") == player_region_id


func _region_income(region_id: String) -> int:
	return int(_region_totals(region_id)["income"])


func _region_manpower_growth(region_id: String) -> int:
	return int(_region_totals(region_id)["manpower_growth"])


func _region_totals(region_id: String) -> Dictionary:
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


func _region_name(region_id: String) -> String:
	if region_id == "" or not regions.has(region_id):
		return "Unknown"
	var raw_name: String = str(regions[region_id].get("name", ""))
	if raw_name.find("茅") != -1 or raw_name.find("么") != -1 or raw_name.find("猫") != -1 or raw_name.find("脦") != -1:
		return _title_from_id(region_id)
	return raw_name


func _title_from_id(region_id: String) -> String:
	var words := PackedStringArray()
	for part in region_id.split("_"):
		if part == "de" or part == "du" or part == "d":
			words.append(part)
		else:
			words.append(part.capitalize())
	return " ".join(words)


func _screen_polygon(province_id: String) -> PackedVector2Array:
	var output := PackedVector2Array()
	for point in province_polygons[province_id]:
		output.append(map_offset + point * map_scale)
	return output


func _province_center_screen(province_id: String) -> Vector2:
	var center: Dictionary = provinces[province_id]["center"]
	return map_offset + Vector2(float(center["x"]), float(center["y"])) * map_scale


func _screen_to_map(screen_pos: Vector2) -> Vector2:
	return (screen_pos - map_offset) / map_scale


func _province_at(map_pos: Vector2) -> String:
	for index in range(province_order.size() - 1, -1, -1):
		var province_id := province_order[index]
		if _point_in_polygon(map_pos, province_polygons[province_id]):
			return province_id
	return ""


func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
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


func _format_int(value) -> String:
	var text := str(int(value))
	var output := ""
	var count := 0
	for index in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			output = "," + output
		output = text.substr(index, 1) + output
		count += 1
	return output


func _format_float(value, decimals: int) -> String:
	var format := "%." + str(decimals) + "f"
	return format % float(value)
