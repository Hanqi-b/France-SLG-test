class_name City
extends Area2D

signal clicked(city)

const OWNER_COLORS := {
	"player": Color(0.25, 0.55, 1.0),
	"enemy": Color(1.0, 0.25, 0.2),
	"neutral": Color(0.55, 0.58, 0.62),
}

var city_name := "City"
var faction := "neutral"
var level := 1
var troops := 10
var income := 5
var grid_pos := Vector2i.ZERO
var selected := false

@onready var label: Label = $Label

func setup(new_name: String, new_faction: String, new_grid_pos: Vector2i, start_troops: int) -> void:
	city_name = new_name
	faction = new_faction
	grid_pos = new_grid_pos
	troops = start_troops


func _ready() -> void:
	input_event.connect(_on_input_event)
	_refresh_label()


func _draw() -> void:
	var color: Color = OWNER_COLORS.get(faction, OWNER_COLORS["neutral"])
	draw_circle(Vector2.ZERO, 28.0, color)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 64, Color.WHITE if selected else Color(0.12, 0.14, 0.16), 4.0)


func produce_gold() -> int:
	return income * level


func produce_troops() -> void:
	troops += level * 4
	_refresh_label()


func upgrade() -> void:
	level += 1
	income += 3
	_refresh_label()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func change_owner(new_faction: String) -> void:
	faction = new_faction
	_refresh_label()
	queue_redraw()


func add_troops(amount: int) -> void:
	troops += amount
	_refresh_label()


func remove_troops(amount: int) -> int:
	var sent: int = min(amount, troops)
	troops -= sent
	_refresh_label()
	return sent


func _refresh_label() -> void:
	if not is_node_ready():
		return

	label.text = "%s\nLv.%d 兵:%d" % [city_name, level, troops]


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
