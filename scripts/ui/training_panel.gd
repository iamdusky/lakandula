extends PanelContainer
## Building panel: shown when a Mactan building is selected. Train buttons
## for each unit the building offers, live queue readout (max 5), and a
## Cancel button that refunds 50%.

var _building: Building = null
var _title: Label
var _buttons_row: HBoxContainer
var _queue_label: Label
var _cancel_button: Button
var _sally_button: Button


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title = Label.new()
	box.add_child(_title)
	_buttons_row = HBoxContainer.new()
	_buttons_row.add_theme_constant_override("separation", 8)
	box.add_child(_buttons_row)
	var queue_row := HBoxContainer.new()
	queue_row.add_theme_constant_override("separation", 8)
	box.add_child(queue_row)
	_queue_label = Label.new()
	_queue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_label.add_theme_font_size_override("font_size", 15)
	queue_row.add_child(_queue_label)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel (50%)"
	_cancel_button.pressed.connect(func() -> void:
		if _building != null:
			_building.cancel_queued())
	queue_row.add_child(_cancel_button)
	_sally_button = Button.new()
	_sally_button.text = "Sally forth"
	_sally_button.visible = false
	_sally_button.pressed.connect(func() -> void:
		if _building != null and is_instance_valid(_building) and "garrisoned" in _building:
			_building.release_garrison())
	queue_row.add_child(_sally_button)
	EventBus.building_selected.connect(_on_building_selected)


func _process(_delta: float) -> void:
	if visible:
		_refresh_queue()


func _on_building_selected(building: Node) -> void:
	_building = building as Building
	if _building == null or _building.faction != "mactan":
		visible = false
		return
	visible = true
	_title.text = _building.display_name
	for child in _buttons_row.get_children():
		child.queue_free()
	for scene in _building.trainable:
		var unit_data := _building._peek_unit_data(scene)
		if unit_data == null:
			continue
		var button := Button.new()
		button.text = "%s (%s)" % [unit_data.display_name, _cost_text(unit_data.cost)]
		var train_scene := scene
		button.pressed.connect(func() -> void:
			if _building != null:
				_building.queue_unit(train_scene))
		_buttons_row.add_child(button)
	_refresh_queue()


func _refresh_queue() -> void:
	if _building == null or not is_instance_valid(_building):
		visible = false
		_building = null
		return
	if "garrisoned" in _building and not _building.garrisoned.is_empty():
		_sally_button.visible = true
		_sally_button.text = "Sally forth (%d)" % _building.garrisoned.size()
	else:
		_sally_button.visible = false
	if _building.queue.is_empty():
		_queue_label.text = "Queue empty"
		_cancel_button.disabled = true
		return
	_cancel_button.disabled = false
	var parts: Array[String] = []
	for i in _building.queue.size():
		var entry: Dictionary = _building.queue[i]
		if i == 0:
			parts.append("%s %.1fs" % [entry["name"], entry["remaining"]])
		else:
			parts.append(entry["name"])
	_queue_label.text = "Queue [%d/%d]: %s" % [
		_building.queue.size(), Building.QUEUE_MAX, " • ".join(parts)]


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in cost:
		parts.append("%d %s" % [cost[resource], resource])
	return ", ".join(parts) if not parts.is_empty() else "free"
