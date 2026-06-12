class_name Army
extends Node2D

signal arrived(army)

var faction := "player"
var troops := 0
var target_city: Node2D
var speed := 180.0

func setup(new_faction: String, amount: int, start: Vector2, target: Node2D) -> void:
	faction = new_faction
	troops = amount
	position = start
	target_city = target


func _process(delta: float) -> void:
	if target_city == null:
		queue_free()
		return

	var direction := target_city.position - position
	var step := speed * delta

	if direction.length() <= step:
		position = target_city.position
		arrived.emit(self)
		queue_free()
	else:
		position += direction.normalized() * step


func _draw() -> void:
	var color := Color(0.25, 0.55, 1.0) if faction == "player" else Color(1.0, 0.25, 0.2)
	draw_circle(Vector2.ZERO, 10.0, color)
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color.WHITE, 2.0)
