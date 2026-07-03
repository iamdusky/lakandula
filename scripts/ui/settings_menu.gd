extends Control
## Settings: audio volumes, resolution, fullscreen, camera scroll speed.
## Everything persists immediately via GameSettings (ConfigFile).

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
]


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	_add_slider(box, "Music volume", GameSettings.music_volume, 0.0, 1.0,
		func(value: float) -> void: GameSettings.set_music_volume(value))
	_add_slider(box, "SFX volume", GameSettings.sfx_volume, 0.0, 1.0,
		func(value: float) -> void: GameSettings.set_sfx_volume(value))
	_add_slider(box, "Scroll speed", GameSettings.scroll_speed_scale, 0.5, 2.0,
		func(value: float) -> void: GameSettings.set_scroll_speed_scale(value))

	var resolution_row := HBoxContainer.new()
	resolution_row.add_theme_constant_override("separation", 12)
	box.add_child(resolution_row)
	var resolution_label := Label.new()
	resolution_label.text = "Resolution"
	resolution_label.custom_minimum_size = Vector2(160, 0)
	resolution_row.add_child(resolution_label)
	var options := OptionButton.new()
	for i in RESOLUTIONS.size():
		options.add_item("%d × %d" % [RESOLUTIONS[i].x, RESOLUTIONS[i].y], i)
		if RESOLUTIONS[i] == GameSettings.resolution:
			options.select(i)
	options.item_selected.connect(func(index: int) -> void:
		GameSettings.set_resolution(RESOLUTIONS[index]))
	resolution_row.add_child(options)

	var fullscreen := CheckBox.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = GameSettings.fullscreen
	fullscreen.toggled.connect(func(pressed: bool) -> void:
		GameSettings.set_fullscreen(pressed))
	box.add_child(fullscreen)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(func() -> void: SceneFlow.goto("res://scenes/ui/main_menu.tscn"))
	box.add_child(back)


func _add_slider(parent: Container, label_text: String, value: float,
		min_value: float, max_value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(280, 0)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
