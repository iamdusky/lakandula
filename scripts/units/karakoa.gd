class_name Karakoa
extends Unit
## War galley with a lantaka swivel cannon. Salvo: instantly fires at up to
## four enemies in extended range.

const LANTAKA_SCENE := preload("res://scenes/projectiles/lantaka.tscn")
const SPLASH_RADIUS := 40.0
const SALVO_COUNT := 4
const SALVO_RANGE_MULT := 1.25


func _ready() -> void:
	super()
	add_to_group("naval_units")
	add_to_group("karakoa")


func _perform_attack(target: Node2D) -> void:
	_fire_lantaka(target)


func use_ability() -> bool:
	if state == State.DEAD or _ability_timer > 0.0:
		return false
	var targets: Array[Unit] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit != null and unit.faction != faction and unit.state != State.DEAD \
				and global_position.distance_to(unit.global_position) <= data.attack_range * SALVO_RANGE_MULT:
			targets.append(unit)
	if targets.is_empty():
		return false
	_ability_timer = data.ability_cooldown
	targets.sort_custom(func(a: Unit, b: Unit) -> bool:
		return global_position.distance_squared_to(a.global_position) \
			< global_position.distance_squared_to(b.global_position))
	for unit in targets.slice(0, SALVO_COUNT):
		_fire_lantaka(unit)
	EventBus.hud_notification.emit("Salvo! Lantaka fire rakes the enemy.")
	return true


func _fire_lantaka(target: Node2D) -> void:
	Effects.cannon_smoke(global_position)
	_spawn_projectile(LANTAKA_SCENE, target, current_damage(), {
		"speed": 360.0,
		"splash_radius": SPLASH_RADIUS,
	})
