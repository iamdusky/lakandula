extends PanelContainer
## Historical codex (toggle with C). Entries unlock as their events happen
## in-game; click a title to read. Session-scoped (persistence arrives with
## the campaign shell, M12).

const ENTRIES := CodexEntries.ENTRIES

var unlocked: Array[String] = []

var _list: VBoxContainer
var _body: Label
var _entry_buttons := {}


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "CODEX (C)"
	box.add_child(title)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(400, 0)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	box.add_child(_body)

	# Entries discovered in past sessions stay readable (GameSettings persists).
	for id: String in GameSettings.codex_unlocked:
		unlock(id, true)

	EventBus.game_started.connect(func() -> void: unlock("lapu_lapu"))
	EventBus.spanish_state_changed.connect(_on_spanish_state)
	EventBus.humabon_flip_stage.connect(func(stage: String) -> void:
		if stage == "enrique":
			unlock("enrique"))
	EventBus.tide_changed.connect(func(phase: String) -> void:
		if phase == "LOW":
			unlock("tide"))
	EventBus.datu_obligated.connect(func(_d: String, _f: String, _t: int) -> void:
		unlock("utang"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_codex"):
		visible = not visible


func unlock(id: String, quiet := false) -> void:
	if id in unlocked or not ENTRIES.has(id):
		return
	unlocked.append(id)
	GameSettings.unlock_codex(id)
	var button := Button.new()
	button.text = ENTRIES[id][0]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: _body.text = ENTRIES[id][1])
	_list.add_child(button)
	_entry_buttons[id] = button
	if not quiet:
		EventBus.hud_notification.emit("Codex updated: %s (C to read)." % ENTRIES[id][0])


func _on_spanish_state(state: String) -> void:
	match state:
		"SAIL_IN":
			unlock("magellan")
		"ESTABLISH":
			unlock("humabon")
		"CONVERT":
			unlock("conversion")
		"ASSAULT":
			unlock("battle_of_mactan")
