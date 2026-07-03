extends PanelContainer
## Utang diplomacy panel (toggle with T). One row per datu village plus
## Rajah Humabon: alignment, tokens held, Gift / Call buttons, and the
## Katipunan Offer button once Humabon reaches 5 tokens.

const FACTION := "mactan"

var _village_rows := {}  # datu_name -> { village, label }
var _humabon_label: Label
var _katipunan_button: Button

@onready var _list: VBoxContainer = $Margin/List


func _ready() -> void:
	visible = false
	_build.call_deferred()
	EventBus.datu_obligated.connect(func(_d: String, _f: String, _t: int) -> void: _refresh())
	EventBus.utang_called.connect(func(_d: String, _f: String) -> void: _refresh())
	EventBus.utang_defaulted.connect(func(_d: String, _f: String) -> void: _refresh())
	EventBus.datu_allied.connect(func(_d: String, _f: String) -> void: _refresh())
	EventBus.humabon_flip_stage.connect(func(_s: String) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_diplomacy"):
		visible = not visible


func _build() -> void:
	var title := Label.new()
	title.text = "UTANG — Diplomacy (T)"
	_list.add_child(title)

	# Humabon row
	var humabon_row := HBoxContainer.new()
	_humabon_label = _make_row_label()
	humabon_row.add_child(_humabon_label)
	var humabon_gift := Button.new()
	humabon_gift.text = "Gift"
	humabon_gift.pressed.connect(func() -> void:
		DiplomacyManager.give_gift(FACTION, DiplomacyManager.HUMABON))
	humabon_row.add_child(humabon_gift)
	_katipunan_button = Button.new()
	_katipunan_button.text = "Katipunan"
	_katipunan_button.visible = false
	_katipunan_button.pressed.connect(func() -> void:
		DiplomacyManager.accept_katipunan_offer())
	humabon_row.add_child(_katipunan_button)
	_list.add_child(humabon_row)

	# Village rows
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village == null:
			continue
		var row := HBoxContainer.new()
		var label := _make_row_label()
		row.add_child(label)
		var gift := Button.new()
		gift.text = "Gift"
		gift.pressed.connect(func() -> void:
			DiplomacyManager.give_gift(FACTION, village.datu_name))
		row.add_child(gift)
		var call := Button.new()
		call.text = "Call"
		call.pressed.connect(func() -> void:
			var action := "fighters" if village.alignment == DatuVillage.Alignment.ALLIED_MACTAN else "supplies"
			DiplomacyManager.call_utang(FACTION, village.datu_name, action))
		row.add_child(call)
		_list.add_child(row)
		_village_rows[village.datu_name] = {"village": village, "label": label}

	_refresh()


func _refresh() -> void:
	if _humabon_label == null:
		return
	var state_text := "Spain's ally"
	match DiplomacyManager.humabon_state:
		DiplomacyManager.HumabonState.NEUTRAL:
			state_text = "Neutral"
		DiplomacyManager.HumabonState.ALLIED_MACTAN:
			state_text = "Allied!"
	_humabon_label.text = "Rajah Humabon — %s — Utang %d" % [
		state_text, DiplomacyManager.get_tokens(DiplomacyManager.HUMABON, FACTION)]
	_katipunan_button.visible = DiplomacyManager.katipunan_offered \
		and DiplomacyManager.humabon_state == DiplomacyManager.HumabonState.SPAIN_ALLY

	for datu_name: String in _village_rows:
		var village: DatuVillage = _village_rows[datu_name]["village"]
		if not is_instance_valid(village):
			continue
		var align_text := "Neutral"
		match village.alignment:
			DatuVillage.Alignment.ALLIED_MACTAN:
				align_text = "Mactan"
			DatuVillage.Alignment.ALLIED_SPAIN:
				align_text = "Spain"
		var label: Label = _village_rows[datu_name]["label"]
		label.text = "%s — %s — Utang %d" % [
			datu_name, align_text, DiplomacyManager.get_tokens(datu_name, FACTION)]


func _make_row_label() -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	return label
