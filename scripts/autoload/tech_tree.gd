extends Node
## Tracks unlocked researches per faction and applies their effects.
## Passive stat effects are queried by units (speed_multiplier,
## damage_multiplier, poison/heal multipliers); one-shot effects fire in
## _apply_effect. Age N+1 unlocks after researching AGE_REQUIREMENT techs
## of age N.
##
## IMPORTANT: unit.gd references this autoload, so this script must NOT
## reference unit classes (Karakoa, Building casts) or autoloads whose
## scripts preload unit scenes (UnitSpawner, DiplomacyManager) at parse time
## — that creates a circular load ("Parse Error: Busy"). Use groups, duck
## typing, and get_node("/root/...") here instead.

const AGE_REQUIREMENT := 2
const FACTION_MACTAN := "mactan"

var researched := {"mactan": [], "spain": []}

var _techs: Dictionary = {}


func _ready() -> void:
	_register_all()
	EventBus.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	researched = {"mactan": [], "spain": []}


func save_state() -> Dictionary:
	return {"mactan": researched["mactan"].duplicate(), "spain": researched["spain"].duplicate()}


## Restores the researched lists only — passive effects are queried live and
## one-shot effects' consequences (building stats, spawned ships, tokens)
## are restored by SaveGame from the world snapshot.
func load_state(data: Dictionary) -> void:
	researched = {"mactan": [], "spain": []}
	for faction in researched:
		for id in data.get(faction, []):
			researched[faction].append(String(id))


func all_techs() -> Array[TechData]:
	var list: Array[TechData] = []
	for id in _techs:
		list.append(_techs[id])
	return list


func get_tech(id: String) -> TechData:
	return _techs.get(id)


func has_tech(faction: String, id: String) -> bool:
	return id in researched.get(faction, [])


func current_age(faction: String) -> int:
	var age := 1
	while age < 3 and _count_age(faction, age) >= AGE_REQUIREMENT:
		age += 1
	return age


func can_research(faction: String, id: String) -> bool:
	var tech: TechData = _techs.get(id)
	if tech == null or has_tech(faction, id):
		return false
	if tech.age > current_age(faction):
		return false
	for prerequisite in tech.prerequisites:
		if not has_tech(faction, prerequisite):
			return false
	return ResourceManager.can_afford(faction, tech.cost)


func research(faction: String, id: String) -> bool:
	if not can_research(faction, id):
		return false
	var tech: TechData = _techs[id]
	if not ResourceManager.spend(faction, tech.cost):
		return false
	researched[faction].append(id)
	_apply_effect(faction, tech)
	EventBus.tech_researched.emit(faction, id)
	EventBus.hud_notification.emit("Research complete: %s." % tech.display_name)
	return true


# --- Passive modifiers (queried by units each frame) ---

func speed_multiplier(unit: Node2D) -> float:
	var multiplier := 1.0
	if unit.faction == FACTION_MACTAN:
		if has_tech(FACTION_MACTAN, "karakoa_rigging") and unit.is_in_group("naval_units"):
			multiplier *= 1.15
	elif has_tech(FACTION_MACTAN, "river_traps"):
		var terrain := TerrainManager.get_terrain_type(unit.global_position)
		if terrain == "river" or terrain == "shallows":
			multiplier *= 0.7
	return multiplier


func damage_multiplier(unit: Node2D) -> float:
	var multiplier := 1.0
	if unit.faction == FACTION_MACTAN:
		# Kris Forging: melee blades only (short-reach attacks).
		if has_tech(FACTION_MACTAN, "kris_forging") and unit.data.attack_range <= 40.0:
			multiplier *= 1.15
		if has_tech(FACTION_MACTAN, "lantaka_upgrades") and unit.is_in_group("karakoa"):
			multiplier *= 1.25
	return multiplier


func poison_multiplier(faction: String) -> float:
	return 1.5 if has_tech(faction, "poison_arrows") else 1.0


func heal_multiplier(faction: String) -> float:
	return 1.5 if has_tech(faction, "babaylan_network") else 1.0


# --- One-shot effects ---

func _apply_effect(faction: String, tech: TechData) -> void:
	match tech.effect_id:
		"war_fleet_assembly":
			_muster_fleet(faction)
		"kuta_reinforcement":
			for building in get_tree().get_nodes_in_group("buildings_" + faction):
				if not building.is_dead():
					building.max_health *= 1.5
					building.armor += 2.0
					building.health = building.max_health
					building.get_node("HealthBar").queue_redraw()
		"great_alliance_pact":
			var diplomacy := get_node("/root/DiplomacyManager")
			for village in get_tree().get_nodes_in_group("datu_villages"):
				# Zero-cost gift: places a token + runs the ally check.
				diplomacy.give_gift(faction, village.datu_name, {"rice": 0})
		_:
			pass  # passive effects are handled by the multiplier queries


func _muster_fleet(faction: String) -> void:
	var shipyard: Node2D = get_tree().current_scene.get_node_or_null("Buildings/Shipyard")
	if shipyard == null or shipyard.is_dead():
		EventBus.hud_notification.emit("War Fleet Assembly: no shipyard remains to build the fleet.")
		return
	var gate: Vector2 = shipyard.global_position + shipyard.gate_offset
	var spawner := get_node("/root/UnitSpawner")
	var karakoa: PackedScene = load("res://scenes/units/karakoa.tscn")
	var balangay: PackedScene = load("res://scenes/units/balangay.tscn")
	spawner.spawn(karakoa, gate, faction, true)
	spawner.spawn(karakoa, gate + Vector2(0, 48), faction, true)
	spawner.spawn(balangay, gate + Vector2(0, -48), faction, true)


# --- Tech definitions ---

func _register_all() -> void:
	var definitions := [
		# [id, name, age, cost, description]
		["poison_arrows", "Poison Arrows", 1, {"rice": 60, "copper": 20},
			"Mamamana venom is 50% stronger."],
		["karakoa_rigging", "Karakoa Rigging", 1, {"rice": 50, "copper": 30},
			"Naval units sail 15% faster."],
		["barangay_alliance", "Barangay Alliance", 1, {"rice": 80, "copper": 10},
			"Allied villages grant +25% income each (up from +15%)."],
		["lantaka_upgrades", "Lantaka Upgrades", 2, {"rice": 40, "copper": 80},
			"Karakoa cannon damage +25%."],
		["kris_forging", "Kris Forging", 2, {"rice": 60, "copper": 60},
			"Melee warriors deal +15% damage."],
		["babaylan_network", "Babaylan Network", 2, {"rice": 70, "honor": 10},
			"Babaylan healing is 50% stronger."],
		["river_traps", "River Traps", 2, {"rice": 50, "copper": 40},
			"Spanish units in rivers and shallows move 30% slower."],
		["war_fleet_assembly", "War Fleet Assembly", 3, {"rice": 200, "copper": 120},
			"A war fleet musters at the Shipyard (2 Karakoa + 1 Balangay)."],
		["kuta_reinforcement", "Kuta Reinforcement", 3, {"rice": 150, "copper": 100},
			"All structures: +50% health, +2 armor, fully repaired."],
		["great_alliance_pact", "Great Alliance Pact", 3, {"rice": 120, "copper": 60, "honor": 15},
			"Envoys place one Utang token on every datu."],
		["monsoon_timing", "Monsoon Timing", 3, {"rice": 100, "honor": 25},
			"Reading the winds: the monsoon arrives on day 50 instead of 60."],
	]
	for def in definitions:
		var tech := TechData.new()
		tech.id = def[0]
		tech.display_name = def[1]
		tech.age = def[2]
		tech.cost = def[3]
		tech.description = def[4]
		tech.effect_id = def[0]
		_techs[tech.id] = tech


func _count_age(faction: String, age: int) -> int:
	var count := 0
	for id in researched.get(faction, []):
		if _techs[id].age == age:
			count += 1
	return count
