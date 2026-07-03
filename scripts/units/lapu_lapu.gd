class_name LapuLapu
extends Hero
## Warrior-king of Mactan. Passive: rally aura (+25% attack speed, 180 px).
## Daluyong (Surge): charges through the enemy formation, damaging and
## staggering every unit hit.

const CHARGE_DISTANCE := 220.0
const CHARGE_SPEED := 700.0
const CHARGE_DAMAGE := 20.0
const CHARGE_STUN := 1.5
const CHARGE_HIT_RADIUS := 48.0
const TARGET_SEARCH_RADIUS := 400.0
const AURA_ATTACK_SPEED := 1.25


func _apply_aura() -> void:
	for node in get_tree().get_nodes_in_group("faction_" + faction):
		var ally := node as Unit
		if ally != null and ally != self and ally.state != State.DEAD \
				and global_position.distance_to(ally.global_position) <= AURA_RADIUS:
			ally.grant_aura(AURA_ATTACK_SPEED, 1.0)


func use_ability() -> bool:
	if state == State.DEAD or _ability_timer > 0.0:
		return false
	var direction := _charge_direction()
	if direction == Vector2.ZERO:
		return false
	_ability_timer = data.ability_cooldown
	EventBus.hud_notification.emit("Daluyong! Lapu-Lapu surges through the enemy line!")
	_charge(direction)
	return true


func _charge_direction() -> Vector2:
	if is_instance_valid(attack_target) and attack_target.state != State.DEAD:
		return global_position.direction_to(attack_target.global_position)
	var best: Unit = null
	var best_distance := TARGET_SEARCH_RADIUS
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit.faction == faction or unit.state == State.DEAD:
			continue
		var distance := global_position.distance_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	return global_position.direction_to(best.global_position) if best != null else Vector2.ZERO


func _charge(direction: Vector2) -> void:
	state = State.ABILITY
	var already_hit: Array[Unit] = []
	var traveled := 0.0
	while traveled < CHARGE_DISTANCE and state == State.ABILITY:
		var delta := get_physics_process_delta_time()
		global_position += direction * CHARGE_SPEED * delta
		traveled += CHARGE_SPEED * delta
		for node in get_tree().get_nodes_in_group("units"):
			var enemy := node as Unit
			if enemy == null or enemy.faction == faction or enemy.state == State.DEAD \
					or enemy in already_hit:
				continue
			if global_position.distance_to(enemy.global_position) <= CHARGE_HIT_RADIUS:
				enemy.take_damage(CHARGE_DAMAGE, self)
				enemy.stun(CHARGE_STUN)
				already_hit.append(enemy)
		await get_tree().physics_frame
	if state == State.ABILITY:
		state = State.IDLE
