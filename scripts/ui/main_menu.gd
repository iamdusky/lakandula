extends Control
## Title screen. When launched with test/tooling args, skips straight to the
## battle map so headless runs behave exactly as before.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args or "--screenshot" in args:
		get_tree().change_scene_to_file.call_deferred("res://scenes/maps/main_map.tscn")
		return
	if "--screenshot-menu" in args:
		add_child(load("res://tools/screenshot_capture.gd").new())

	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "LAKANDULA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "The Battle of Mactan — April 1521"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.8, 0.8, 0.75)
	box.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	box.add_child(spacer)

	_add_button(box, "Play", func() -> void:
		SceneFlow.goto("res://scenes/ui/mission_briefing.tscn"))
	_add_button(box, "Historical Codex", func() -> void:
		SceneFlow.goto("res://scenes/ui/historical_codex.tscn"))
	_add_button(box, "Settings", func() -> void:
		SceneFlow.goto("res://scenes/ui/settings_menu.tscn"))
	_add_button(box, "Quit", func() -> void:
		get_tree().quit())


func _add_button(parent: Container, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 44)
	button.pressed.connect(action)
	parent.add_child(button)
