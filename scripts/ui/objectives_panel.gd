extends PanelContainer
## Campaign objectives tracker (top-left, campaign mode only).
## Reads phase state from VictoryManager; refreshes on objective_changed.
##   ✓ completed (dim green) · ▶ active (bright) · · upcoming (dim)

var _labels: Array[Label] = []
var _liberation_label: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	var title := Label.new()
	title.text = "THE WAR FOR MACTAN"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(0.95, 0.85, 0.6)
	box.add_child(title)
	for i in VictoryManager.PHASE_TITLES.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 14)
		box.add_child(label)
		_labels.append(label)
	_liberation_label = Label.new()
	_liberation_label.add_theme_font_size_override("font_size", 14)
	_liberation_label.modulate = Color(0.95, 0.85, 0.6)
	box.add_child(_liberation_label)
	EventBus.objective_changed.connect(
		func(_phase: int, _title: String, _state: String) -> void: _refresh())
	EventBus.game_started.connect(_refresh)
	EventBus.datu_allied.connect(func(_datu: String, _faction: String) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	visible = VictoryManager.campaign_active()
	if not visible:
		_liberation_label.visible = false
		return
	for i in _labels.size():
		if i < VictoryManager.campaign_phase:
			_labels[i].text = "✓ " + VictoryManager.PHASE_TITLES[i]
			_labels[i].modulate = Color(0.55, 0.75, 0.55)
		elif i == VictoryManager.campaign_phase:
			_labels[i].text = "▶ " + VictoryManager.PHASE_TITLES[i]
			_labels[i].modulate = Color(1.0, 1.0, 1.0)
		else:
			_labels[i].text = "· " + VictoryManager.PHASE_TITLES[i]
			_labels[i].modulate = Color(0.55, 0.55, 0.55)
	var converted := 0
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village != null and village.alignment == DatuVillage.Alignment.ALLIED_SPAIN:
			converted += 1
	_liberation_label.visible = converted > 0
	if converted > 0:
		_liberation_label.text = "⚑ Liberate the barangays — %d under Spain" % converted
