class_name Babaylan
extends Unit
## Healer-priestess. Passively mends nearby wounded allies. Ritwal: exposes
## all enemies for a time (fog of war pierces in Milestone 8; the signal is
## emitted now so listeners can hook in).

const HEAL_RADIUS := 140.0
const HEAL_PER_TICK := 4.0
const HEAL_INTERVAL := 1.0
const RITWAL_DURATION := 10.0

var _heal_accumulator := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	_heal_accumulator += delta
	if _heal_accumulator >= HEAL_INTERVAL:
		_heal_accumulator = 0.0
		_heal_nearby()


func use_ability() -> bool:
	if state == State.DEAD or _ability_timer > 0.0:
		return false
	_ability_timer = data.ability_cooldown
	EventBus.ritual_reveal.emit(RITWAL_DURATION)
	EventBus.hud_notification.emit("Ritwal! The spirits unveil every hidden enemy.")
	return true


func _heal_nearby() -> void:
	for node in get_tree().get_nodes_in_group("faction_" + faction):
		var ally := node as Unit
		if ally != null and ally != self and ally.state != State.DEAD \
				and ally.health < ally.data.max_health \
				and global_position.distance_to(ally.global_position) <= HEAL_RADIUS:
			ally.heal(HEAL_PER_TICK * TechTree.heal_multiplier(faction))
