extends Node
## Owns the day clock and all win/loss conditions. Emits
## EventBus.game_over(winner, condition) exactly once, then pauses the tree
## (the GameOverScreen listens and unpauses on retry).
##
## SKIRMISH (GameSettings.game_mode, read live): the original parallel
## conditions. Mactan victory: magellan_killed, powder_starvation (0 powder
## for 120 s), monsoon (Kuta standing on day 60), great_alliance (6 datus +
## Humabon). Spain victory: kuta_razed, lapu_lapu_killed, full_conversion
## (6 datus Spanish before day 30).
##
## CAMPAIGN (M17): staged objectives — LANDING (hold to day 15) → ASSAULT
## (break it: day 22 or attackers thinned) → CONQUISTADOR (kill Magellan —
## a turning point: it triggers the Reprisal, not victory) → REPRISAL
## (endure ~8 days of leaderless fury) → EXPEL (destroy every Spanish unit
## and building, winning "spain_expelled"). Monsoon / powder starvation /
## great alliance remain global alternate victories; all losses persist.

## Seconds of real time per in-game day. Day 40 = Spain's deadline,
## Day 60 = monsoon; at 30 s/day a full game runs ~30 minutes.
const DAY_LENGTH := 30.0
const MONSOON_DAY := 60
const FULL_CONVERSION_DEADLINE := 30
const POWDER_STARVATION_TIME := 120.0
const TOTAL_VILLAGES := 6

# --- Campaign (M17) ---
enum CampaignPhase { LANDING, ASSAULT, CONQUISTADOR, REPRISAL, EXPEL, DONE }

const PHASE_TITLES: Array[String] = [
	"Weather the Landing",
	"Break the Assault",
	"Fell the Conquistador",
	"Endure the Reprisal",
	"Expel Spain",
]
## Mirrors SpanishAI.DAY_ASSAULT — the landing is weathered when the real
## assault begins.
const CAMPAIGN_ASSAULT_DAY := 15
## The assault counts as broken when this day passes with the Kuta intact…
const ASSAULT_BROKEN_DAY := 22
## …or when Spain's non-passive land troops on the island thin out to this.
const ASSAULT_BROKEN_ATTACKERS := 3
const REPRISAL_DAYS := 8
## West edge of Mactan's shallows; Spanish units east of it are "ashore".
const ISLAND_WEST_X := -448.0
const CAMPAIGN_POLL_INTERVAL := 0.5

var game_active := false
var current_day := 1
## Monsoon Timing tech moves this to 50.
var monsoon_day := MONSOON_DAY
var campaign_phase: int = CampaignPhase.LANDING

var _day_timer := 0.0
var _powder_zero_time := 0.0
var _humabon_allied := false
var _reprisal_start_day := 0
var _campaign_poll := 0.0


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


## Live read — the mode is chosen at the briefing and persists in settings.
func campaign_active() -> bool:
	return GameSettings.game_mode == "campaign"


func start_game() -> void:
	game_active = true
	current_day = 1
	_day_timer = 0.0
	_powder_zero_time = 0.0
	_humabon_allied = false
	monsoon_day = MONSOON_DAY
	campaign_phase = CampaignPhase.LANDING
	_reprisal_start_day = 0
	_campaign_poll = 0.0
	EventBus.game_started.emit()
	if campaign_active():
		EventBus.objective_changed.emit(
			campaign_phase, PHASE_TITLES[campaign_phase], "active")


func save_state() -> Dictionary:
	return {
		"current_day": current_day,
		"day_timer": _day_timer,
		"monsoon_day": monsoon_day,
		"powder_zero_time": _powder_zero_time,
		"humabon_allied": _humabon_allied,
		"campaign_phase": campaign_phase,
		"reprisal_start_day": _reprisal_start_day,
	}


func load_state(data: Dictionary) -> void:
	current_day = int(data.get("current_day", 1))
	_day_timer = data.get("day_timer", 0.0)
	monsoon_day = int(data.get("monsoon_day", MONSOON_DAY))
	_powder_zero_time = data.get("powder_zero_time", 0.0)
	_humabon_allied = data.get("humabon_allied", false)
	campaign_phase = int(data.get("campaign_phase", CampaignPhase.LANDING))
	_reprisal_start_day = int(data.get("reprisal_start_day", 0))
	game_active = true
	EventBus.day_advanced.emit(current_day)  # refresh HUD
	if campaign_active() and campaign_phase < CampaignPhase.DONE:
		EventBus.objective_changed.emit(
			campaign_phase, PHASE_TITLES[campaign_phase], "active")


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
	if campaign_active():
		_campaign_poll += delta
		if _campaign_poll >= CAMPAIGN_POLL_INTERVAL:
			_campaign_poll = 0.0
			_poll_campaign()


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
		return
	if campaign_active() and campaign_phase == CampaignPhase.LANDING \
			and current_day >= CAMPAIGN_ASSAULT_DAY:
		_advance_phase(CampaignPhase.ASSAULT)


func _on_hero_died(hero: Node) -> void:
	if hero is Magellan:
		if campaign_active():
			# The turning point, not the credits: leaderless Spain lashes out.
			if campaign_phase <= CampaignPhase.CONQUISTADOR:
				_reprisal_start_day = current_day
				_advance_phase(CampaignPhase.REPRISAL)
		else:
			end_game("mactan", "magellan_killed")
	elif hero is LapuLapu:
		end_game("spain", "lapu_lapu_killed")


# --- Campaign phase machine ---

func _poll_campaign() -> void:
	match campaign_phase:
		CampaignPhase.ASSAULT:
			if current_day >= ASSAULT_BROKEN_DAY \
					or _spanish_attackers_on_island() < ASSAULT_BROKEN_ATTACKERS:
				_advance_phase(CampaignPhase.CONQUISTADOR)
				EventBus.hud_notification.emit(
					"The assault is broken — now for the conquistador himself.")
		CampaignPhase.REPRISAL:
			if current_day >= _reprisal_start_day + REPRISAL_DAYS \
					or _spanish_combat_units() == 0:
				_advance_phase(CampaignPhase.EXPEL)
				EventBus.hud_notification.emit(
					"The fury is spent. Drive what remains of Spain into the sea.")
		CampaignPhase.EXPEL:
			if _spain_eliminated():
				EventBus.objective_changed.emit(
					CampaignPhase.EXPEL, PHASE_TITLES[CampaignPhase.EXPEL], "completed")
				campaign_phase = CampaignPhase.DONE
				end_game("mactan", "spain_expelled")


func _advance_phase(to: int) -> void:
	for phase in range(campaign_phase, to):
		EventBus.objective_changed.emit(phase, PHASE_TITLES[phase], "completed")
	campaign_phase = to
	EventBus.objective_changed.emit(to, PHASE_TITLES[to], "active")


func _spanish_attackers_on_island() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("faction_spain"):
		var unit := node as Unit
		if unit != null and unit.state != Unit.State.DEAD and not unit.data.passive \
				and not unit.is_in_group("naval_units") \
				and unit.global_position.x > ISLAND_WEST_X:
			count += 1
	return count


func _spanish_combat_units() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("faction_spain"):
		var unit := node as Unit
		if unit != null and unit.state != Unit.State.DEAD and not unit.data.passive:
			count += 1
	return count


## Expulsion is total: every unit (friars included) and every structure.
func _spain_eliminated() -> bool:
	for node in get_tree().get_nodes_in_group("faction_spain"):
		var unit := node as Unit
		if unit != null and unit.state != Unit.State.DEAD:
			return false
	for node in get_tree().get_nodes_in_group("buildings_spain"):
		if not node.is_dead():
			return false
	return true


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
