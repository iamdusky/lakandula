extends Node
## Click select, drag-box select, right-click move/attack, Q ability, Space stop.
## Only Mactan units are selectable. Commands go straight to Unit methods;
## state changes broadcast through EventBus.

const DRAG_THRESHOLD := 8.0
const CLICK_RADIUS := 20.0
const FORMATION_SPACING := 44.0

var selected_units: Array[Unit] = []
var selected_building: Building = null

var _dragging := false
var _drag_start := Vector2.ZERO
var _box: ColorRect
var _attack_move_armed := false
var _control_groups := {}
var _idle_cycle_index := -1
var _last_recall_group := 0
var _last_recall_msec := 0


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_box = ColorRect.new()
	_box.color = Color(0.45, 0.95, 0.55, 0.18)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	layer.add_child(_box)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		if _attack_move_armed:
			_attack_move_armed = false
			_issue_attack_move(_world_mouse())
			return
		_dragging = true
		_drag_start = _screen_mouse()
	elif event.is_action_released("select"):
		if not _dragging:
			return
		_dragging = false
		_box.visible = false
		if _drag_start.distance_to(_screen_mouse()) < DRAG_THRESHOLD:
			_point_select()
		else:
			_box_select()
	elif event.is_action_pressed("command"):
		var mouse := event as InputEventMouseButton
		if _attack_move_armed or (mouse != null and (mouse.ctrl_pressed or mouse.meta_pressed)):
			_attack_move_armed = false
			_issue_attack_move(_world_mouse())
		else:
			_issue_command()
	elif event.is_action_pressed("attack_move"):
		if not _live_selection().is_empty():
			_attack_move_armed = true
			EventBus.hud_notification.emit("Attack-move: click a destination.")
	elif event.is_action_pressed("cycle_idle"):
		cycle_idle_unit()
	elif event.is_action_pressed("ability"):
		for unit in _live_selection():
			unit.use_ability()
	elif event.is_action_pressed("stop"):
		_attack_move_armed = false
		for unit in _live_selection():
			unit.stop()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_hotkeys(event)


func _handle_hotkeys(event: InputEventKey) -> void:
	var with_modifier: bool = event.ctrl_pressed or event.meta_pressed
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var group_index: int = event.keycode - KEY_1 + 1
		if with_modifier:
			assign_control_group(group_index)
		else:
			recall_control_group(group_index)
	elif event.keycode == KEY_A and with_modifier:
		select_all_military()


func _process(_delta: float) -> void:
	if not _dragging:
		return
	var current := _screen_mouse()
	if _drag_start.distance_to(current) < DRAG_THRESHOLD:
		return
	var rect := Rect2(_drag_start, current - _drag_start).abs()
	_box.visible = true
	_box.position = rect.position
	_box.size = rect.size


func select_units(units: Array) -> void:
	_clear_building_selection()
	for unit in _live_selection():
		unit.set_selected(false)
	selected_units.clear()
	for unit in units:
		if unit is Unit and is_instance_valid(unit):
			selected_units.append(unit)
			unit.set_selected(true)
	EventBus.selection_changed.emit(selected_units)


func select_building(building: Building) -> void:
	select_units([])  # also clears any previous building
	selected_building = building
	EventBus.building_selected.emit(building)


func clear_selection() -> void:
	select_units([])


func _clear_building_selection() -> void:
	if selected_building != null:
		selected_building = null
		EventBus.building_selected.emit(null)


# --- Selection internals ---

func _point_select() -> void:
	var world := _world_mouse()
	var best: Unit = null
	var best_distance := CLICK_RADIUS
	for node in get_tree().get_nodes_in_group("faction_mactan"):
		var unit := node as Unit
		if unit == null or unit.state == Unit.State.DEAD:
			continue
		var distance := world.distance_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	if best == null:
		# No unit under the cursor — try one of our buildings.
		for node in get_tree().get_nodes_in_group("buildings_mactan"):
			var building := node as Building
			if building != null and not building.is_dead() \
					and world.distance_to(building.global_position) <= building.attack_radius:
				select_building(building)
				return
	select_units([best] if best != null else [])


func _box_select() -> void:
	var rect := Rect2(_drag_start, _screen_mouse() - _drag_start).abs()
	var transform := get_viewport().get_canvas_transform()
	var picked: Array = []
	for node in get_tree().get_nodes_in_group("faction_mactan"):
		var unit := node as Unit
		if unit != null and unit.state != Unit.State.DEAD \
				and rect.has_point(transform * unit.global_position):
			picked.append(unit)
	select_units(picked)


# --- Control groups & army selection ---

func assign_control_group(index: int) -> void:
	_control_groups[index] = _live_selection().duplicate()


func recall_control_group(index: int) -> void:
	var live: Array = _control_groups.get(index, []).filter(
		func(unit: Unit) -> bool:
			return is_instance_valid(unit) and unit.state != Unit.State.DEAD)
	_control_groups[index] = live
	if live.is_empty():
		return
	select_units(live)
	# Double-tap recenters the camera on the group.
	var now := Time.get_ticks_msec()
	if index == _last_recall_group and now - _last_recall_msec < 400:
		_pan_camera_to_selection()
	_last_recall_group = index
	_last_recall_msec = now


func select_all_military() -> void:
	var army: Array = []
	for node in get_tree().get_nodes_in_group("faction_mactan"):
		var unit := node as Unit
		if unit != null and unit.state != Unit.State.DEAD:
			army.append(unit)
	select_units(army)


func cycle_idle_unit() -> void:
	var idle: Array = []
	for node in get_tree().get_nodes_in_group("faction_mactan"):
		var unit := node as Unit
		if unit != null and unit.state == Unit.State.IDLE:
			idle.append(unit)
	if idle.is_empty():
		return
	_idle_cycle_index = (_idle_cycle_index + 1) % idle.size()
	select_units([idle[_idle_cycle_index]])
	_pan_camera_to_selection()


func _pan_camera_to_selection() -> void:
	if selected_units.is_empty():
		return
	var centroid := Vector2.ZERO
	for unit in selected_units:
		centroid += unit.global_position
	centroid /= selected_units.size()
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.has_method("pan_to"):
		camera.pan_to(centroid)


# --- Commands ---

func _issue_command() -> void:
	var units := _live_selection()
	if units.is_empty():
		# A selected production building takes RMB as its rally point.
		if selected_building != null and is_instance_valid(selected_building) \
				and selected_building.faction == "mactan":
			selected_building.set_rally_point(_world_mouse())
		return
	var world := _world_mouse()
	var enemy := _enemy_at(world)
	if enemy != null:
		for unit in units:
			unit.command_attack(enemy)
		EventBus.command_issued.emit("attack", enemy)
	else:
		var offsets := _formation_offsets(units.size())
		for i in units.size():
			units[i].command_move(world + offsets[i])
		EventBus.command_issued.emit("move", world)


func _issue_attack_move(world: Vector2) -> void:
	var units := _live_selection()
	if units.is_empty():
		return
	var offsets := _formation_offsets(units.size())
	for i in units.size():
		units[i].command_attack_move(world + offsets[i])
	EventBus.command_issued.emit("attack_move", world)


func _enemy_at(world: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := CLICK_RADIUS
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit.faction == "mactan" or unit.state == Unit.State.DEAD \
				or not unit.visible:  # hidden in fog — not targetable
			continue
		var distance := world.distance_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or building.faction == "mactan" or building.is_dead():
			continue
		var distance := world.distance_to(building.global_position)
		if distance <= building.attack_radius and (best == null or distance < best_distance):
			best = building
			best_distance = distance
	return best


func _formation_offsets(count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var cols := ceili(sqrt(float(count)))
	for i in count:
		var col := i % cols
		var row := i / cols
		offsets.append(Vector2(
			(col - (cols - 1) * 0.5) * FORMATION_SPACING,
			(row - (ceili(float(count) / cols) - 1) * 0.5) * FORMATION_SPACING,
		))
	return offsets


# --- Helpers ---

func _live_selection() -> Array[Unit]:
	var live: Array[Unit] = []
	for unit in selected_units:
		if is_instance_valid(unit) and unit.state != Unit.State.DEAD:
			live.append(unit)
	selected_units = live
	return live


func _screen_mouse() -> Vector2:
	return get_viewport().get_mouse_position()


func _world_mouse() -> Vector2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
