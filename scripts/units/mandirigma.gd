class_name Mandirigma
extends Unit
## Mactan warrior. Fights hardest in the jungle (terrain_damage bonus in
## mandirigma.tres). Sigaw: a war cry that rallies nearby Mactan units.

const SIGAW_RADIUS := 180.0
const SIGAW_SPEED_MULT := 1.3
const SIGAW_DAMAGE_MULT := 1.3
const SIGAW_DURATION := 5.0


func use_ability() -> bool:
	if state == State.DEAD or _ability_timer > 0.0:
		return false
	_ability_timer = data.ability_cooldown
	for node in get_tree().get_nodes_in_group("faction_" + faction):
		var ally := node as Unit
		if ally != null and global_position.distance_to(ally.global_position) <= SIGAW_RADIUS:
			ally.apply_temp_buff(SIGAW_SPEED_MULT, SIGAW_DAMAGE_MULT, SIGAW_DURATION)
	EventBus.hud_notification.emit("Sigaw! Nearby warriors surge with courage.")
	return true
