extends Node
## Tracks both factions' resources. Passive income arrives in Milestone 1.
## Design rule: never subtract from these dicts directly — always use spend().

const FACTION_MACTAN := "mactan"
const FACTION_SPAIN := "spain"

const INCOME_INTERVAL := 5.0
const MACTAN_BASE_INCOME := {"rice": 10, "copper": 2, "honor": 1}
const SPAIN_BASE_INCOME := {"gold": 5}
## Each allied datu village adds +15% to Mactan income (+25% with the
## Barangay Alliance tech).
const ALLY_INCOME_BONUS := 0.15
var ally_income_bonus := ALLY_INCOME_BONUS

## datu_name -> faction string; source of truth for the Mactan ally count.
var _datu_allegiance := {}

## Humabon's tribute funds Spain's gold income: starts when Spain makes
## contact (ESTABLISH), stops for good when Humabon flips.
var _spain_tribute_active := false
var _humabon_flipped := false

const STARTING_RESOURCES := {
	FACTION_MACTAN: {
		"rice": 200,
		"copper": 50,
		"honor": 0,
		"allies": 0,
	},
	FACTION_SPAIN: {
		"gold": 300,
		"powder": 100,
		"faith": 0,
	},
}

var resources := STARTING_RESOURCES.duplicate(true)


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = INCOME_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_on_income_tick)
	add_child(timer)
	EventBus.datu_allied.connect(_on_datu_allied)
	EventBus.humabon_flip_stage.connect(_on_humabon_flip_stage)
	EventBus.spanish_state_changed.connect(_on_spanish_state_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.tech_researched.connect(_on_tech_researched)


func _on_tech_researched(faction: String, tech_id: String) -> void:
	if faction == FACTION_MACTAN and tech_id == "barangay_alliance":
		ally_income_bonus = 0.25


## Fresh economy on every game start (retry reloads the scene, not autoloads).
func _on_game_started() -> void:
	resources = STARTING_RESOURCES.duplicate(true)
	resources[FACTION_SPAIN]["powder"] = GameSettings.difficulty_value("start_powder")
	_datu_allegiance.clear()
	_spain_tribute_active = false
	_humabon_flipped = false
	ally_income_bonus = ALLY_INCOME_BONUS
	EventBus.resources_changed.emit(FACTION_MACTAN, resources[FACTION_MACTAN])
	EventBus.resources_changed.emit(FACTION_SPAIN, resources[FACTION_SPAIN])


func _on_humabon_flip_stage(stage: String) -> void:
	if stage == "neutral" or stage == "allied":
		_humabon_flipped = true
		_spain_tribute_active = false


func _on_spanish_state_changed(state: String) -> void:
	if state == "ESTABLISH" and not _humabon_flipped:
		_spain_tribute_active = true


func _on_datu_allied(datu: String, faction: String) -> void:
	_datu_allegiance[datu] = faction
	var count := 0
	for allegiance in _datu_allegiance.values():
		if allegiance == FACTION_MACTAN:
			count += 1
	resources[FACTION_MACTAN]["allies"] = count
	EventBus.resources_changed.emit(FACTION_MACTAN, resources[FACTION_MACTAN])


func _on_income_tick() -> void:
	var multiplier: float = 1.0 + ally_income_bonus * resources[FACTION_MACTAN]["allies"]
	var gains := {}
	for resource in MACTAN_BASE_INCOME:
		gains[resource] = roundi(MACTAN_BASE_INCOME[resource] * multiplier)
	add(FACTION_MACTAN, gains)
	if _spain_tribute_active:
		add(FACTION_SPAIN, {"gold": GameSettings.difficulty_value("tribute_gold")})


func save_state() -> Dictionary:
	return {
		"resources": resources.duplicate(true),
		"datu_allegiance": _datu_allegiance.duplicate(),
		"tribute": _spain_tribute_active,
		"humabon_flipped": _humabon_flipped,
		"ally_income_bonus": ally_income_bonus,
	}


func load_state(data: Dictionary) -> void:
	var loaded: Dictionary = data.get("resources", {})
	for faction in resources:
		for resource in resources[faction]:
			resources[faction][resource] = int(loaded.get(faction, {}).get(resource, resources[faction][resource]))
	_datu_allegiance = data.get("datu_allegiance", {}).duplicate()
	_spain_tribute_active = data.get("tribute", false)
	_humabon_flipped = data.get("humabon_flipped", false)
	ally_income_bonus = data.get("ally_income_bonus", ALLY_INCOME_BONUS)
	EventBus.resources_changed.emit(FACTION_MACTAN, resources[FACTION_MACTAN])
	EventBus.resources_changed.emit(FACTION_SPAIN, resources[FACTION_SPAIN])


func get_amount(faction: String, resource: String) -> int:
	return resources.get(faction, {}).get(resource, 0)


func can_afford(faction: String, cost: Dictionary) -> bool:
	for resource in cost:
		if get_amount(faction, resource) < cost[resource]:
			return false
	return true


func spend(faction: String, cost: Dictionary) -> bool:
	if not can_afford(faction, cost):
		EventBus.resource_spend_failed.emit(faction, cost)
		return false
	for resource in cost:
		resources[faction][resource] -= cost[resource]
	EventBus.resources_changed.emit(faction, resources[faction])
	return true


func add(faction: String, gains: Dictionary) -> void:
	for resource in gains:
		if resources[faction].has(resource):
			resources[faction][resource] += gains[resource]
	EventBus.resources_changed.emit(faction, resources[faction])
