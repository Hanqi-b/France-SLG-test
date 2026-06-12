extends Node2D

const GameRules = preload("res://scripts/game_rules.gd")
const MapDataLoader = preload("res://scripts/map_data_loader.gd")
const DisplayUtils = preload("res://scripts/display_utils.gd")
const ProvinceSidebar = preload("res://scripts/province_sidebar.gd")
const PlayerRegionPanel = preload("res://scripts/player_region_panel.gd")

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

var provinces: Dictionary = {}
var regions: Dictionary = {}
var province_order: Array[String] = []
var province_polygons: Dictionary = {}
var province_to_region: Dictionary = {}
var province_state: Dictionary = {}
var selected_province_id := ""
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
var sidebar_panel
var sidebar_handle: Control
var right_panel
var start_overlay: Control

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
	if not game_started and start_overlay != null:
		return

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
	var province_json := MapDataLoader.read_json(PROVINCES_PATH)
	var region_json := MapDataLoader.read_json(REGIONS_PATH)

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
		province_polygons[province_id] = MapDataLoader.outline_to_polygon(provinces[province_id]["outline"])

	province_to_region = MapDataLoader.build_province_to_region(regions)


func _initialize_runtime_state() -> void:
	province_state = GameRules.build_initial_province_state(provinces, province_order)


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
	sidebar_panel = ProvinceSidebar.new()
	ui.add_child(sidebar_panel)
	sidebar_panel.build()
	sidebar_panel.economic_develop_requested.connect(_on_economic_develop_pressed)
	sidebar_panel.manpower_develop_requested.connect(_on_manpower_develop_pressed)

	sidebar_handle = Control.new()
	sidebar_handle.name = "SidebarResizeHandle"
	sidebar_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	sidebar_handle.gui_input.connect(_on_sidebar_handle_input)
	ui.add_child(sidebar_handle)


func _create_right_panel(ui: CanvasLayer) -> void:
	right_panel = PlayerRegionPanel.new()
	ui.add_child(right_panel)
	right_panel.build()
	right_panel.end_turn_requested.connect(_on_end_turn_pressed)


func _create_start_overlay(ui: CanvasLayer) -> void:
	start_overlay = Control.new()
	start_overlay.name = "RegionSelectOverlay"
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(start_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 520)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_top = -260
	panel.offset_right = 280
	panel.offset_bottom = 260
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
		button.text = DisplayUtils.region_name(regions, region_id)
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
	if game_started:
		return

	player_region_id = region_id
	game_started = true
	if start_overlay != null:
		start_overlay.hide()
		start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_overlay.call_deferred("queue_free")
		start_overlay = null
	_refresh_player_panel()
	queue_redraw()


func _show_initial_state() -> void:
	sidebar_panel.show_initial()
	_refresh_player_panel()


func _select_at(screen_position: Vector2) -> void:
	var province_id := _province_at(_screen_to_map(screen_position))
	if province_id == "":
		return

	selected_province_id = province_id
	_show_province(province_id)
	queue_redraw()


func _on_economic_develop_pressed() -> void:
	if not _selected_province_is_owned():
		sidebar_panel.set_status("只能发展自己大区的省份")
		return

	var cost := GameRules.economic_development_cost(province_state, selected_province_id)
	if treasury < cost:
		sidebar_panel.set_status("国库不足：需要 %d" % cost)
		return

	var state: Dictionary = province_state[selected_province_id]
	treasury -= cost
	state["economic_development"] = int(state["economic_development"]) + 1
	GameRules.recalculate_province_values(province_state, selected_province_id)
	_show_province(selected_province_id)
	_refresh_player_panel()
	sidebar_panel.set_status("%s 经济发展提升到 %d" % [provinces[selected_province_id]["name"], int(state["economic_development"])])


func _on_manpower_develop_pressed() -> void:
	if not _selected_province_is_owned():
		sidebar_panel.set_status("只能发展自己大区的省份")
		return

	var cost := GameRules.manpower_development_cost(province_state, selected_province_id)
	if manpower < cost:
		sidebar_panel.set_status("人力不足：需要 %d" % cost)
		return

	var state: Dictionary = province_state[selected_province_id]
	manpower -= cost
	state["manpower_development"] = int(state["manpower_development"]) + 1
	GameRules.recalculate_province_values(province_state, selected_province_id)
	_show_province(selected_province_id)
	_refresh_player_panel()
	sidebar_panel.set_status("%s 人力发展提升到 %d" % [provinces[selected_province_id]["name"], int(state["manpower_development"])])


func _on_end_turn_pressed() -> void:
	if not game_started:
		return

	var income := GameRules.region_income(regions, provinces, province_state, player_region_id)
	var manpower_growth := GameRules.region_manpower_growth(regions, provinces, province_state, player_region_id)
	last_turn_income = income
	last_turn_manpower_growth = manpower_growth
	treasury += income
	manpower += manpower_growth
	turn += 1
	_refresh_player_panel()

	if selected_province_id != "":
		_show_province(selected_province_id)

	sidebar_panel.set_status("本回合收入 +%d，人力 +%d" % [income, manpower_growth])


func _show_province(province_id: String) -> void:
	var province: Dictionary = provinces[province_id]
	var stats: Dictionary = province["stats"]["2022"]
	var economy: Dictionary = stats["economy"]
	var state: Dictionary = province_state[province_id]
	var region_id: String = province_to_region.get(province_id, "")
	var owned := region_id == player_region_id
	var economic_cost := GameRules.economic_development_cost(province_state, province_id)
	var manpower_cost := GameRules.manpower_development_cost(province_state, province_id)

	sidebar_panel.show_province(
		province_id,
		province,
		DisplayUtils.region_name(regions, region_id),
		state,
		stats,
		economy,
		owned,
		economic_cost,
		manpower_cost
	)


func _refresh_player_panel() -> void:
	if right_panel == null:
		return

	if not game_started:
		right_panel.show_empty()
		return

	var summary := GameRules.region_totals(regions, provinces, province_state, player_region_id)
	right_panel.show_region(DisplayUtils.region_name(regions, player_region_id), turn, treasury, manpower, summary)


func _selected_province_is_owned() -> bool:
	if selected_province_id == "":
		return false
	return province_to_region.get(selected_province_id, "") == player_region_id


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
		if DisplayUtils.point_in_polygon(map_pos, province_polygons[province_id]):
			return province_id
	return ""
