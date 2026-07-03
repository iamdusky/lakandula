class_name Magellan
extends Unit
## Ferdinand Magellan. Mounted conquistador hero with a long-range crossbow.
## Baptism: instantly converts the nearest neutral datu village within reach.
## Unlike Mactan heroes he does NOT respawn — killing him is the player's
## primary victory condition (wired in Milestone 7 via EventBus.hero_died).

const CROSSBOW_SCENE := preload("res://scenes/projectiles/arrow.tscn")
const BAPTISM_RADIUS := 220.0


func _ready() -> void:
	super()
	add_to_group("heroes")


func _perform_attack(target: Node2D) -> void:
	_spawn_projectile(CROSSBOW_SCENE, target, current_damage(), {"speed": 620.0})


func use_ability() -> bool:
	if state == State.DEAD or _ability_timer > 0.0:
		return false
	var best: DatuVillage = null
	var best_distance := BAPTISM_RADIUS
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village != null and village.alignment == DatuVillage.Alignment.NEUTRAL:
			var distance := global_position.distance_to(village.global_position)
			if distance < best_distance:
				best = village
				best_distance = distance
	if best == null:
		return false
	_ability_timer = data.ability_cooldown
	best.ally(faction)
	EventBus.hud_notification.emit("Baptism! %s kneels before the cross." % best.datu_name)
	return true


func _on_died() -> void:
	EventBus.hero_died.emit(self)
	EventBus.hud_notification.emit("Magellan has fallen! The Spanish resolve shatters.")
