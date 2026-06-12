extends Control

signal quit_requested


func build() -> void:
	name = "PauseMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 100

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 110)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -160
	panel.offset_top = -55
	panel.offset_right = 160
	panel.offset_bottom = 55
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var quit_button := Button.new()
	quit_button.text = "退出游戏"
	quit_button.custom_minimum_size = Vector2(240, 42)
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quit_button)


func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return visible
