class_name RajahSulayman
extends Hero
## Ally hero from Maynila. Passive: war aura (+15% damage, 180 px).
## Sunugin (Burn It): scorched earth — destroys the nearest friendly
## structure so Spain cannot take it. (Buildings arrive in Milestone 3;
## until then this fizzles with a notification.)

const SUNUGIN_RADIUS := 400.0
const AURA_DAMAGE := 1.15


func _apply_aura() -> void:
	for node in get_tree().get_nodes_in_group("faction_" + faction):
		var ally := node as Unit
		if ally != null and ally != self and ally.state != State.DEAD \
				and global_position.distance_to(ally.global_position) <= AURA_RADIUS:
			ally.grant_aura(1.0, AURA_DAMAGE)


func use_ability() -> bool:
	if state == State.DEAD or _ability_timer > 0.0:
		return false
	var target: Node2D = null
	var best_distance := SUNUGIN_RADIUS
	for node in get_tree().get_nodes_in_group("buildings_mactan"):
		var building := node as Node2D
		if building != null and building.has_method("sunugin"):
			var distance := global_position.distance_to(building.global_position)
			if distance < best_distance:
				target = building
				best_distance = distance
	if target == null:
		EventBus.hud_notification.emit("Sunugin: no structure within reach to burn.")
		return false
	_ability_timer = data.ability_cooldown
	target.sunugin()
	EventBus.hud_notification.emit("Sunugin! %s burns rather than surrenders." % target.name)
	return true
