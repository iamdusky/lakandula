class_name Babaylan
extends Unit
## Healer-priestess. Passively mends nearby wounded allies. Ritwal: exposes
## all enemies for a time (fog of war pierces in Milestone 8; the signal is
## emitted now so listeners can hook in).

const HEAL_RADIUS := 140.0
const HEAL_PER_TICK := 4.0
const HEAL_INTERVAL := 1.0
const RITWAL_DURATION := 10.0

## Reclamation (M18, campaign-only): a babaylan can undo a friar's
## conversion, mirroring Fraile's approach but flipping a Spain-held
## village back to neutral.
const LIBERATE_RADIUS := 110.0
const LIBERATE_CHALLENGE_RADIUS := 160.0
const LIBERATE_TIME := 12.0
const LIBERATE_SCAN_INTERVAL := 0.25

var _heal_accumulator := 0.0

var _liberate_progress := 0.0
var _liberate_scan_accumulator := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	_heal_accumulator += delta
	if _heal_accumulator >= HEAL_INTERVAL:
		_heal_accumulator = 0.0
		_heal_nearby()
	if GameSettings.game_mode == "campaign":
		_liberate_scan_accumulator += delta
		if _liberate_scan_accumulator >= LIBERATE_SCAN_INTERVAL:
			_scan_liberation(_liberate_scan_accumulator)
			_liberate_scan_accumulator = 0.0


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


func _scan_liberation(scan_delta: float) -> void:
	var village := _spain_village_in_reach()
	if village == null:
		_liberate_progress = 0.0
		return
	if _challenged():
		return
	var starting_fresh := _liberate_progress == 0.0
	_liberate_progress += scan_delta
	if starting_fresh:
		EventBus.hud_notification.emit(
			"The babaylan begins the cleansing rites at %s." % village.datu_name)
	if _liberate_progress >= LIBERATE_TIME:
		_liberate_progress = 0.0
		village.ally("neutral")
		EventBus.hud_notification.emit(
			"%s is freed — the friars' hold is broken." % village.datu_name)


func _spain_village_in_reach() -> DatuVillage:
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village != null and village.alignment == DatuVillage.Alignment.ALLIED_SPAIN \
				and global_position.distance_to(village.global_position) <= LIBERATE_RADIUS:
			return village
	return null


func _challenged() -> bool:
	for node in get_tree().get_nodes_in_group("faction_spain"):
		var enemy := node as Unit
		if enemy != null and not enemy.data.passive and enemy.state != State.DEAD \
				and global_position.distance_to(enemy.global_position) <= LIBERATE_CHALLENGE_RADIUS:
			return true
	return false
