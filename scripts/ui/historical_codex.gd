extends Control
## Main-menu codex: all entries listed; locked ones stay hidden until their
## in-game event has been witnessed (persisted via GameSettings).


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var title := Label.new()
	title.text = "Historical Codex"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	var body := Label.new()
	body.custom_minimum_size = Vector2(640, 120)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "Entries unlock as you witness their events in battle."

	for id: String in CodexEntries.ENTRIES:
		var entry: Array = CodexEntries.ENTRIES[id]
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if id in GameSettings.codex_unlocked:
			button.text = entry[0]
			var entry_body: String = entry[1]
			button.pressed.connect(func() -> void: body.text = entry_body)
		else:
			button.text = "??? — undiscovered"
			button.disabled = true
		box.add_child(button)

	box.add_child(body)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(func() -> void: SceneFlow.goto("res://scenes/ui/main_menu.tscn"))
	box.add_child(back)
