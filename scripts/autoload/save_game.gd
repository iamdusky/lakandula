extends Node
## Mid-game save/load (user://save.json). Managers expose save_state() /
## load_state(); this autoload orchestrates them plus the scene world
## (units, buildings, villages). Loading re-enters the battle scene, lets
## the normal game_started reset run, then overwrites everything.
##
## Known limits (documented in PLAN.md): projectiles in flight, fog
## exploration, capture tints, and heroes mid-respawn are not preserved.

const PATH := "user://save.json"
const VERSION := 1

var _pending: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save() -> bool:
	if not VictoryManager.game_active:
		return false
	var data := {
		"version": VERSION,
		"difficulty": GameSettings.difficulty,
		"victory": VictoryManager.save_state(),
		"resources": ResourceManager.save_state(),
		"diplomacy": DiplomacyManager.save_state(),
		"tech": TechTree.save_state(),
		"tide": TideManager.save_state(),
		"ai": SpanishAI.save_state(),
		"stats": GameStats.save_state(),
		"units": _save_units(),
		"buildings": _save_buildings(),
		"villages": _save_villages(),
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


## Re-enter the battle scene and apply the save once it has started.
func load_into_battle() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		return false
	_pending = parsed
	GameSettings.difficulty = _pending.get("difficulty", GameSettings.difficulty)
	EventBus.game_started.connect(_on_game_started, CONNECT_ONE_SHOT)
	SceneFlow.goto("res://scenes/maps/main_map.tscn")
	return true


func _on_game_started() -> void:
	_apply.call_deferred()  # after every game_started handler (incl. AI spawns)


func _apply() -> void:
	var data := _pending
	_pending = {}
	VictoryManager.load_state(data.get("victory", {}))
	ResourceManager.load_state(data.get("resources", {}))
	DiplomacyManager.load_state(data.get("diplomacy", {}))
	TechTree.load_state(data.get("tech", {}))
	TideManager.load_state(data.get("tide", {}))
	GameStats.load_state(data.get("stats", {}))

	# World: clear the fresh spawns, then restore the saved ones.
	for node in get_tree().get_nodes_in_group("units"):
		node.free()
	var buildings: Dictionary = data.get("buildings", {})
	for node in get_tree().get_nodes_in_group("buildings"):
		var entry: Variant = buildings.get(node.name)
		if entry == null:
			node.free()  # was destroyed in the saved game
			continue
		node.max_health = entry.get("max_health", node.max_health)
		node.armor = entry.get("armor", node.armor)
		node.health = entry.get("health", node.health)
		if entry.get("rally_x") != null:
			node.rally_point = Vector2(entry["rally_x"], entry["rally_y"])
		node.get_node("HealthBar").queue_redraw()
	var villages: Dictionary = data.get("villages", {})
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var allegiance: String = villages.get(node.datu_name, "")
		if allegiance != "":
			node.ally(allegiance)
	for entry in data.get("units", []):
		var scene: PackedScene = load(entry["scene"])
		var unit := UnitSpawner.spawn(
			scene, Vector2(entry["x"], entry["y"]), entry["faction"], true)
		if unit != null:
			unit.health = entry.get("health", unit.health)
			unit.invulnerable = entry.get("invulnerable", false)
			unit.get_node("HealthBar").queue_redraw()

	SpanishAI.load_state(data.get("ai", {}))  # last: relinks Magellan
	EventBus.hud_notification.emit("Game loaded.")


func _save_units() -> Array:
	var units := []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit.state == Unit.State.DEAD:
			continue
		units.append({
			"scene": unit.scene_file_path,
			"faction": unit.faction,
			"x": unit.global_position.x,
			"y": unit.global_position.y,
			"health": unit.health,
			"invulnerable": unit.invulnerable,
		})
	return units


func _save_buildings() -> Dictionary:
	var buildings := {}
	for node in get_tree().get_nodes_in_group("buildings"):
		if node.is_dead():
			continue
		var entry := {
			"health": node.health,
			"max_health": node.max_health,
			"armor": node.armor,
		}
		if node.rally_point != Vector2.INF:
			entry["rally_x"] = node.rally_point.x
			entry["rally_y"] = node.rally_point.y
		buildings[String(node.name)] = entry
	return buildings


func _save_villages() -> Dictionary:
	var villages := {}
	for node in get_tree().get_nodes_in_group("datu_villages"):
		match node.alignment:
			DatuVillage.Alignment.ALLIED_MACTAN:
				villages[node.datu_name] = "mactan"
			DatuVillage.Alignment.ALLIED_SPAIN:
				villages[node.datu_name] = "spain"
	return villages
