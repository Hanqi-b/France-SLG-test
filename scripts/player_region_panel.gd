extends PanelContainer

const DisplayUtils = preload("res://scripts/display_utils.gd")
const GOLD_ICON := "res://photo/gold.png"
const MANPOWER_ICON := "res://photo/manpower.png"
const TERRITORY_ICON := "res://photo/territory.png"
const FLAG_DIR := "res://photo/deviantart_region_flags/"

var flag_texture: TextureRect
var player_title: Label
var turn_label: Label
var treasury_value: Label
var manpower_value: Label
var territory_value: Label
var end_turn_button: Button


func build() -> void:
	name = "PlayerTopBar"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var identity := HBoxContainer.new()
	identity.custom_minimum_size = Vector2(330, 72)
	identity.add_theme_constant_override("separation", 12)
	row.add_child(identity)

	flag_texture = TextureRect.new()
	flag_texture.custom_minimum_size = Vector2(96, 64)
	flag_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	identity.add_child(flag_texture)

	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 2)
	identity.add_child(title_box)

	player_title = Label.new()
	player_title.text = "选择大区"
	player_title.add_theme_font_size_override("font_size", 20)
	title_box.add_child(player_title)

	turn_label = Label.new()
	turn_label.text = "回合: -"
	title_box.add_child(turn_label)

	row.add_child(_create_stat_item(GOLD_ICON, "0", "treasury_value"))
	row.add_child(_create_stat_item(MANPOWER_ICON, "0", "manpower_value"))
	row.add_child(_create_stat_item(TERRITORY_ICON, "0", "territory_value"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.custom_minimum_size = Vector2(110, 40)
	end_turn_button.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(end_turn_button)


func _create_stat_item(icon_path: String, initial_value: String, label_name: String) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.custom_minimum_size = Vector2(150, 64)
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	item.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_png_texture(icon_path)
	item.add_child(icon)

	var value := Label.new()
	value.name = label_name
	value.text = initial_value
	value.add_theme_font_size_override("font_size", 22)
	item.add_child(value)

	if label_name == "treasury_value":
		treasury_value = value
	elif label_name == "manpower_value":
		manpower_value = value
	elif label_name == "territory_value":
		territory_value = value

	return item


func show_empty() -> void:
	flag_texture.texture = null
	player_title.text = "选择大区"
	turn_label.text = "回合: -"
	treasury_value.text = "-"
	manpower_value.text = "-"
	territory_value.text = "-"
	end_turn_button.disabled = true


func show_region(region_id: String, region_name: String, turn: int, treasury: int, manpower: int, summary: Dictionary) -> void:
	flag_texture.texture = _load_png_texture(FLAG_DIR + region_id + ".png")
	player_title.text = region_name
	turn_label.text = "回合: %d" % turn
	treasury_value.text = DisplayUtils.format_int(treasury)
	manpower_value.text = DisplayUtils.format_int(manpower)
	territory_value.text = DisplayUtils.format_int(summary["province_count"])
	end_turn_button.disabled = false


func _load_png_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_warning("Could not load texture: " + path)
		return null
	return ImageTexture.create_from_image(image)
