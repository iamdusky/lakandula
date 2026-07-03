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
		_issue_command()
	elif event.is_action_pressed("ability"):
		for unit in _live_selection():
			unit.use_ability()
	elif event.is_action_pressed("stop"):
		for unit in _live_selection():
			unit.stop()


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


# --- Commands ---

func _issue_command() -> void:
	var units := _live_selection()
	if units.is_empty():
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
