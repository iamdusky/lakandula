class_name Building
extends StaticBody2D
## Base class for all structures: health/armor, faction groups, production
## queue (up to 5 units), and sunugin() — instant self-destruct for scorched
## earth. Trained units emerge at gate_offset from the building.

signal queue_changed

const QUEUE_MAX := 5

@export var display_name := "Building"
@export var max_health := 400.0
@export var armor := 2.0
@export var faction := "mactan"
## Effective size for attacker range checks (attackers measure distance to
## edge, not center).
@export var attack_radius := 48.0
@export var trainable: Array[PackedScene] = []
@export var gate_offset := Vector2(0, 80)

var health := 0.0
## Production queue: [{ "scene": PackedScene, "remaining": float }]
var queue: Array[Dictionary] = []
## Trained units walk here after emerging at the gate (RMB with the
## building selected). Vector2.INF = no rally.
var rally_point := Vector2.INF

@onready var _health_bar: Node2D = $HealthBar


func _ready() -> void:
	health = max_health
	add_to_group("buildings")
	add_to_group("buildings_" + faction)


func _process(delta: float) -> void:
	if queue.is_empty():
		return
	queue[0]["remaining"] -= delta
	if queue[0]["remaining"] <= 0.0:
		var entry: Dictionary = queue.pop_front()
		var unit := UnitSpawner.spawn(entry["scene"], global_position + gate_offset, faction, true)
		if unit != null and rally_point != Vector2.INF:
			unit.command_move(rally_point)
		queue_changed.emit()


## Pays the unit's cost up front (Milestone 9's cancel button refunds 50%).
func queue_unit(scene: PackedScene) -> bool:
	if is_dead() or queue.size() >= QUEUE_MAX:
		return false
	var unit_data := _peek_unit_data(scene)
	if unit_data == null:
		return false
	if not ResourceManager.can_afford(faction, unit_data.cost):
		EventBus.resource_spend_failed.emit(faction, unit_data.cost)
		return false
	ResourceManager.spend(faction, unit_data.cost)
	queue.append({
		"scene": scene,
		"remaining": unit_data.train_time,
		"cost": unit_data.cost.duplicate(),
		"name": unit_data.display_name,
	})
	queue_changed.emit()
	return true


## Remove a queued unit (default: last) and refund 50% of its cost.
func cancel_queued(index := -1) -> bool:
	if queue.is_empty():
		return false
	if index < 0:
		index = queue.size() - 1
	if index >= queue.size():
		return false
	var entry: Dictionary = queue[index]
	queue.remove_at(index)
	var refund := {}
	for resource in entry["cost"]:
		refund[resource] = int(entry["cost"][resource] * 0.5)
	ResourceManager.add(faction, refund)
	queue_changed.emit()
	return true


func set_rally_point(world_pos: Vector2) -> void:
	rally_point = world_pos
	queue_redraw()


func _draw() -> void:
	if rally_point == Vector2.INF:
		return
	var local := to_local(rally_point)
	draw_line(Vector2.ZERO, local, Color(0.45, 0.95, 0.55, 0.30), 1.5)
	draw_line(local, local + Vector2(0, -12), Color(0.9, 0.85, 0.7), 2.0)
	draw_colored_polygon(PackedVector2Array([
		local + Vector2(0, -12), local + Vector2(9, -9), local + Vector2(0, -6),
	]), Color(0.45, 0.95, 0.55))


func take_damage(amount: float, _source: Node = null, ignore_armor := false) -> void:
	if is_dead() or amount <= 0.0:
		return
	health = maxf(0.0, health - (amount if ignore_armor else maxf(amount - armor, 1.0)))
	_health_bar.queue_redraw()
	EventBus.combat_hit.emit(self)
	if health <= 0.0:
		_destroy()


func is_dead() -> bool:
	return health <= 0.0


func get_max_health() -> float:
	return max_health


## Scorched earth: destroy this structure so the enemy can't take it.
func sunugin() -> void:
	if is_dead():
		return
	health = 0.0
	_destroy()


func _destroy() -> void:
	Effects.fire_burst(global_position)
	EventBus.building_destroyed.emit(self)
	_on_destroyed()
	queue_free()


## Override for structure-specific death behavior.
func _on_destroyed() -> void:
	pass


func _peek_unit_data(scene: PackedScene) -> UnitData:
	var unit := scene.instantiate() as Unit
	if unit == null:
		push_error("Building.queue_unit: %s is not a Unit scene" % scene.resource_path)
		return null
	var unit_data := unit.data
	unit.free()
	return unit_data
