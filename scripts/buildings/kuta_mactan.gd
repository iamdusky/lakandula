class_name KutaMactanBuilding
extends Building
## The main fortress of Mactan. Its destruction is Spain's primary victory
## condition (VictoryManager polls the "kuta" group from Milestone 7).
##
## Garrison (M18): units can shelter inside the walls (invulnerable, hidden)
## and fire arrows out at nearby Spanish while garrisoned.

const GARRISON_MAX := 6
const WALL_FIRE_INTERVAL := 1.2
const WALL_FIRE_RANGE := 220.0
const WALL_FIRE_DAMAGE_MULT := 0.8
const ARROW_SCENE := preload("res://scenes/projectiles/arrow.tscn")

var garrisoned: Array[Unit] = []

var _wall_fire_accumulator := 0.0


func _ready() -> void:
	super()
	add_to_group("kuta")


func _process(delta: float) -> void:
	super(delta)
	_wall_fire_accumulator += delta
	if _wall_fire_accumulator < WALL_FIRE_INTERVAL:
		return
	_wall_fire_accumulator = 0.0
	garrisoned = garrisoned.filter(
		func(unit: Unit) -> bool: return is_instance_valid(unit) and not unit.is_dead())
	for unit in garrisoned:
		var target := _nearest_spanish()
		if target != null:
			var arrow := ARROW_SCENE.instantiate()
			get_tree().current_scene.add_child(arrow)
			arrow.global_position = global_position
			arrow.setup(target, unit.current_damage() * WALL_FIRE_DAMAGE_MULT, unit, {"speed": 520.0})


func garrison_unit(unit: Unit) -> bool:
	if is_dead() or garrisoned.size() >= GARRISON_MAX:
		return false
	if unit == null or not is_instance_valid(unit) or unit.is_dead():
		return false
	garrisoned.append(unit)
	unit.stop()
	unit.set_selected(false)
	unit.visible = false
	unit.invulnerable = true
	return true


func release_garrison() -> void:
	for i in garrisoned.size():
		var unit := garrisoned[i]
		if unit == null or not is_instance_valid(unit):
			continue
		unit.visible = true
		unit.invulnerable = false
		unit.global_position = global_position + gate_offset + Vector2(-45 + 30 * i, 0)
	garrisoned.clear()


func _nearest_spanish() -> Node2D:
	var best: Unit = null
	var best_distance := WALL_FIRE_RANGE
	for node in get_tree().get_nodes_in_group("faction_spain"):
		var unit := node as Unit
		if unit == null or unit.is_dead() or unit.data.passive or not unit.visible:
			continue
		var distance := global_position.distance_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	return best


func _on_destroyed() -> void:
	for unit in garrisoned:
		if unit == null or not is_instance_valid(unit):
			continue
		unit.visible = true
		unit.invulnerable = false
		unit.take_damage(999999.0, null, true)
	garrisoned.clear()
	EventBus.hud_notification.emit("The Kuta has fallen!")
