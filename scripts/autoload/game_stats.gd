extends Node
## Session statistics for the post-game screen. Event-driven; resets on
## game_started. "Kills" approximates: any non-Mactan unit death counts
## (there is no per-killer attribution).

var stats := {
	"units_lost": 0,
	"units_killed": 0,
	"buildings_lost": 0,
	"villages_allied": 0,
	"villages_converted": 0,
	"techs_researched": 0,
}


func _ready() -> void:
	EventBus.game_started.connect(_reset)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.building_destroyed.connect(_on_building_destroyed)
	EventBus.datu_allied.connect(_on_datu_allied)
	EventBus.tech_researched.connect(_on_tech_researched)


func summary() -> String:
	return "Day %d  ·  Warriors lost %d  ·  Enemies slain %d\nVillages allied %d  ·  Converted by Spain %d  ·  Techs %d" % [
		VictoryManager.current_day, stats["units_lost"], stats["units_killed"],
		stats["villages_allied"], stats["villages_converted"], stats["techs_researched"]]


func save_state() -> Dictionary:
	return stats.duplicate()


func load_state(data: Dictionary) -> void:
	for key in stats:
		stats[key] = int(data.get(key, 0))


func _reset() -> void:
	for key in stats:
		stats[key] = 0


func _on_unit_died(unit: Node) -> void:
	if unit.faction == "mactan":
		stats["units_lost"] += 1
	else:
		stats["units_killed"] += 1


func _on_building_destroyed(building: Node) -> void:
	if building.faction == "mactan":
		stats["buildings_lost"] += 1


func _on_datu_allied(_datu: String, faction: String) -> void:
	if faction == "mactan":
		stats["villages_allied"] += 1
	elif faction == "spain":
		stats["villages_converted"] += 1


func _on_tech_researched(faction: String, _id: String) -> void:
	if faction == "mactan":
		stats["techs_researched"] += 1
