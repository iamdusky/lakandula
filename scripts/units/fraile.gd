class_name Fraile
extends Unit
## Missionary friar. No combat. Standing within a neutral datu village's
## bounds, he converts it after 15 unchallenged seconds; any Mactan unit
## nearby pauses the sermon.

const CONVERT_RADIUS := 110.0
const CHALLENGE_RADIUS := 160.0
const CONVERT_TIME := 15.0
## Group scans are throttled (perf) — conversion advances in SCAN_INTERVAL steps.
const SCAN_INTERVAL := 0.25

var _progress := 0.0

var _scan_accumulator := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	_scan_accumulator += delta
	if _scan_accumulator < SCAN_INTERVAL:
		return
	var village := _village_in_reach()
	if village == null:
		_progress = 0.0
	elif not _challenged():
		_progress += _scan_accumulator
		if _progress >= CONVERT_TIME:
			_progress = 0.0
			village.ally(faction)
	_scan_accumulator = 0.0


func _village_in_reach() -> DatuVillage:
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village != null and village.alignment == DatuVillage.Alignment.NEUTRAL \
				and global_position.distance_to(village.global_position) <= CONVERT_RADIUS:
			return village
	return null


func _challenged() -> bool:
	for node in get_tree().get_nodes_in_group("faction_mactan"):
		var enemy := node as Unit
		if enemy != null and enemy.state != State.DEAD \
				and global_position.distance_to(enemy.global_position) <= CHALLENGE_RADIUS:
			return true
	return false
