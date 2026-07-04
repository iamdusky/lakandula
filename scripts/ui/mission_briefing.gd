extends Control
## Pre-battle briefing: historical context, objectives, map preview.

const BRIEFING := """April 1521. Ferdinand Magellan's fleet lies at anchor off Cebu. Rajah Humabon has taken baptism and pays the strangers tribute; his rivals are being 'converted' one barangay at a time.

Across the strait, Lapu-Lapu of Mactan refuses. Spain will come for him — first with friars, then with arquebuses.

Hold Mactan. Watch the tide: at low water the galleons run aground and the shallows open to your warriors. Win the datus with gifts — their utang is your army. The monsoon arrives in sixty days; Spain must win before then, and you must make sure they don't."""

const OBJECTIVES := """PROTECT: the Kuta and Lapu-Lapu himself — losing either ends the resistance.
VICTORY: kill Magellan · starve their powder · survive to the monsoon · forge the Great Alliance."""


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.08, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "The Battle of Mactan"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)

	var body := Label.new()
	body.text = BRIEFING
	body.custom_minimum_size = Vector2(560, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(body)

	var preview := TextureRect.new()
	preview.texture = MapData.build_preview_texture()
	preview.custom_minimum_size = Vector2(320, 200)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(preview)

	var objectives := Label.new()
	objectives.text = OBJECTIVES
	objectives.custom_minimum_size = Vector2(900, 0)
	objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objectives.modulate = Color(0.95, 0.85, 0.6)
	box.add_child(objectives)

	var difficulty_row := HBoxContainer.new()
	difficulty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty_row.add_theme_constant_override("separation", 12)
	box.add_child(difficulty_row)
	var difficulty_label := Label.new()
	difficulty_label.text = "Difficulty"
	difficulty_row.add_child(difficulty_label)
	var difficulty_options := OptionButton.new()
	var levels := ["easy", "normal", "hard"]
	for i in levels.size():
		difficulty_options.add_item(levels[i].capitalize(), i)
		if levels[i] == GameSettings.difficulty:
			difficulty_options.select(i)
	difficulty_options.item_selected.connect(func(index: int) -> void:
		GameSettings.set_difficulty(levels[index]))
	difficulty_row.add_child(difficulty_options)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(func() -> void: SceneFlow.goto("res://scenes/ui/main_menu.tscn"))
	buttons.add_child(back)
	var play := Button.new()
	play.text = "To Battle"
	play.custom_minimum_size = Vector2(220, 44)
	play.pressed.connect(func() -> void: SceneFlow.goto("res://scenes/maps/main_map.tscn"))
	buttons.add_child(play)
