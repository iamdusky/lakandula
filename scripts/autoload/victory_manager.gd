extends Node
## Owns the day clock and all win/loss conditions. Emits
## EventBus.game_over(winner, condition) exactly once, then pauses the tree
## (the GameOverScreen listens and unpauses on retry).
##
## Mactan victory: magellan_killed, powder_starvation (0 powder for 120 s),
## monsoon (Kuta standing on day 60), great_alliance (6 datus + Humabon).
## Spain victory: kuta_razed, lapu_lapu_killed, full_conversion (6 datus
## Spanish before day 30).

## Seconds of real time per in-game day. Day 40 = Spain's deadline,
## Day 60 = monsoon; at 30 s/day a full game runs ~30 minutes.
const DAY_LENGTH := 30.0
const MONSOON_DAY := 60
const FULL_CONVERSION_DEADLINE := 30
const POWDER_STARVATION_TIME := 120.0
const TOTAL_VILLAGES := 6

var game_active := false
var current_day := 1
## Monsoon Timing tech moves this to 50.
var monsoon_day := MONSOON_DAY

var _day_timer := 0.0
var _powder_zero_time := 0.0
var _humabon_allied := false


func _ready() -> void:
	EventBus.hero_died.connect(_on_hero_died)
	EventBus.building_destroyed.connect(_on_building_destroyed)
	EventBus.datu_allied.connect(_on_datu_allied)
	EventBus.humabon_flip_stage.connect(_on_humabon_flip_stage)
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.tech_researched.connect(_on_tech_researched)


func _on_tech_researched(faction: String, tech_id: String) -> void:
	if faction == "mactan" and tech_id == "monsoon_timing":
		monsoon_day = 50
		EventBus.hud_notification.emit("The winds are read — the monsoon will arrive by day 50.")


func start_game() -> void:
	game_active = true
	current_day = 1
	_day_timer = 0.0
	_powder_zero_time = 0.0
	_humabon_allied = false
	monsoon_day = MONSOON_DAY
	EventBus.game_started.emit()


func save_state() -> Dictionary:
	return {
		"current_day": current_day,
		"day_timer": _day_timer,
		"monsoon_day": monsoon_day,
		"powder_zero_time": _powder_zero_time,
		"humabon_allied": _humabon_allied,
	}


func load_state(data: Dictionary) -> void:
	current_day = int(data.get("current_day", 1))
	_day_timer = data.get("day_timer", 0.0)
	monsoon_day = int(data.get("monsoon_day", MONSOON_DAY))
	_powder_zero_time = data.get("powder_zero_time", 0.0)
	_humabon_allied = data.get("humabon_allied", false)
	game_active = true
	EventBus.day_advanced.emit(current_day)  # refresh HUD


func end_game(winner: String, condition: String) -> void:
	if not game_active:
		return
	game_active = false
	EventBus.game_over.emit(winner, condition)
	get_tree().paused = true


func _process(delta: float) -> void:
	if not game_active:
		return
	_day_timer += delta
	if _day_timer >= DAY_LENGTH:
		_day_timer -= DAY_LENGTH
		current_day += 1
		EventBus.day_advanced.emit(current_day)
	_poll_powder_starvation(delta)


# --- Conditions ---

func _poll_powder_starvation(delta: float) -> void:
	if ResourceManager.get_amount("spain", "powder") <= 0:
		_powder_zero_time += delta
		if _powder_zero_time >= POWDER_STARVATION_TIME:
			end_game("mactan", "powder_starvation")
	else:
		_powder_zero_time = 0.0


func _on_day_advanced(day: int) -> void:
	current_day = maxi(current_day, day)
	if current_day >= monsoon_day and _kuta_standing():
		end_game("mactan", "monsoon")


func _on_hero_died(hero: Node) -> void:
	if hero is Magellan:
		end_game("mactan", "magellan_killed")
	elif hero is LapuLapu:
		end_game("spain", "lapu_lapu_killed")


func _on_building_destroyed(building: Node) -> void:
	if building.is_in_group("kuta"):
		end_game("spain", "kuta_razed")


func _on_datu_allied(_datu: String, _faction: String) -> void:
	_check_alliances()


func _on_humabon_flip_stage(stage: String) -> void:
	if stage == "allied":
		_humabon_allied = true
		_check_alliances()


func _check_alliances() -> void:
	var mactan := 0
	var spain := 0
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village == null:
			continue
		match village.alignment:
			DatuVillage.Alignment.ALLIED_MACTAN:
				mactan += 1
			DatuVillage.Alignment.ALLIED_SPAIN:
				spain += 1
	if spain >= TOTAL_VILLAGES and current_day < FULL_CONVERSION_DEADLINE:
		end_game("spain", "full_conversion")
	elif mactan >= TOTAL_VILLAGES and _humabon_allied:
		end_game("mactan", "great_alliance")


func _kuta_standing() -> bool:
	var kuta := get_tree().get_first_node_in_group("kuta") as Building
	return kuta != null and not kuta.is_dead()
