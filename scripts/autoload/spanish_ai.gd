extends Node
## Spain's campaign AI. State ladder (forward-only), driven by
## EventBus.day_advanced and the powder supply:
##   SAIL_IN (game start) -> ESTABLISH (day 5) -> CONVERT (day 8)
##   -> ASSAULT (day 15) -> DESPERATE (powder < 20 or day > 35)
## Fleet is invulnerable until the landing (historical grace period).
## Powder resupply ship arrives every 20 minutes.

enum State { IDLE, SAIL_IN, ESTABLISH, CONVERT, ASSAULT, DESPERATE }

const TICK := 2.0
const WAVE_INTERVAL := 50.0
const POWDER_RESUPPLY_INTERVAL := 1200.0
const POWDER_RESUPPLY_AMOUNT := 60
const POWDER_CRITICAL := 20

const DAY_ESTABLISH := 5
const DAY_CONVERT := 8
const DAY_ASSAULT := 15
const DAY_DESPERATE := 36

const SOLDADO_SCENE := preload("res://scenes/units/soldado_tercio.tscn")
const ARCABUCERO_SCENE := preload("res://scenes/units/arcabucero.tscn")
const JINETE_SCENE := preload("res://scenes/units/jinete.tscn")
const FRAILE_SCENE := preload("res://scenes/units/fraile.tscn")
const GALEON_SCENE := preload("res://scenes/units/galeon.tscn")
const BERGANTIN_SCENE := preload("res://scenes/units/bergantin.tscn")
const MAGELLAN_SCENE := preload("res://scenes/units/magellan.tscn")

const FACTION := "spain"
## Fleet spawns in the strait, sails for the shallows off the landing beach.
const FLEET_SPAWN := Vector2(-832, 0)
const FLEET_ANCHOR := Vector2(-448, 128)
## Troops land beside the Spanish camp on the south beach.
const LANDING_ZONE := Vector2(-288, 256)

var state: State = State.IDLE
var magellan: Unit = null

var _tick_accumulator := 0.0
var _wave_accumulator := 0.0
var _wave_number := 0
var _powder_warning_sent := false
var _resupply_timer: Timer = null


func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.day_advanced.connect(_on_day_advanced)


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	_tick_accumulator += delta
	if _tick_accumulator >= TICK:
		_tick_accumulator = 0.0
		_tick()


func _on_game_started() -> void:
	state = State.IDLE
	magellan = null
	_tick_accumulator = 0.0
	_wave_accumulator = 0.0
	_wave_number = 0
	_powder_warning_sent = false
	_enter_state(State.SAIL_IN)
	if _resupply_timer == null:
		_resupply_timer = Timer.new()
		_resupply_timer.wait_time = POWDER_RESUPPLY_INTERVAL
		_resupply_timer.autostart = true
		_resupply_timer.timeout.connect(_on_powder_resupply)
		add_child(_resupply_timer)
	else:
		_resupply_timer.start()


func _on_day_advanced(day: int) -> void:
	if day >= DAY_DESPERATE:
		_advance_to(State.DESPERATE)
	elif day >= DAY_ASSAULT:
		_advance_to(State.ASSAULT)
	elif day >= DAY_CONVERT:
		_advance_to(State.CONVERT)
	elif day >= DAY_ESTABLISH:
		_advance_to(State.ESTABLISH)


func _advance_to(target: State) -> void:
	if target > state:
		_enter_state(target)


func _enter_state(new_state: State) -> void:
	state = new_state
	EventBus.spanish_state_changed.emit(State.keys()[new_state])
	match new_state:
		State.SAIL_IN:
			_spawn_fleet()
		State.ESTABLISH:
			_land_troops()
		State.CONVERT:
			_spawn_frailes()
		State.ASSAULT:
			_begin_assault()
		State.DESPERATE:
			_go_desperate()


func _tick() -> void:
	if state >= State.ESTABLISH and state != State.DESPERATE \
			and ResourceManager.get_amount(FACTION, "powder") < POWDER_CRITICAL:
		_enter_state(State.DESPERATE)
		return
	match state:
		State.CONVERT:
			_task_frailes()
			_maintain_frailes()
		State.ASSAULT:
			_task_frailes()
			_maintain_frailes()
			_wave_accumulator += TICK
			if _wave_accumulator >= float(GameSettings.difficulty_value("wave_interval")):
				_wave_accumulator = 0.0
				_spawn_wave()
		State.DESPERATE:
			_press_the_assault()


func save_state() -> Dictionary:
	return {
		"state": state,
		"wave_accumulator": _wave_accumulator,
		"wave_number": _wave_number,
		"powder_warning_sent": _powder_warning_sent,
		"resupply_left": _resupply_timer.time_left if _resupply_timer != null else POWDER_RESUPPLY_INTERVAL,
	}


## Called after saved units are respawned — relinks Magellan.
func load_state(data: Dictionary) -> void:
	state = int(data.get("state", State.SAIL_IN)) as State
	_wave_accumulator = data.get("wave_accumulator", 0.0)
	_wave_number = int(data.get("wave_number", 0))
	_powder_warning_sent = data.get("powder_warning_sent", false)
	if _resupply_timer != null:
		_resupply_timer.start(maxf(1.0, data.get("resupply_left", POWDER_RESUPPLY_INTERVAL)))
	magellan = null
	for node in get_tree().get_nodes_in_group("heroes"):
		if node.faction == FACTION:
			magellan = node
			break


# --- State entries ---

func _spawn_fleet() -> void:
	var fleet: Array[Unit] = []
	fleet.append(UnitSpawner.spawn(GALEON_SCENE, FLEET_SPAWN + Vector2(0, -64), FACTION, true))
	fleet.append(UnitSpawner.spawn(GALEON_SCENE, FLEET_SPAWN + Vector2(-32, 64), FACTION, true))
	fleet.append(UnitSpawner.spawn(BERGANTIN_SCENE, FLEET_SPAWN + Vector2(96, 0), FACTION, true))
	for i in fleet.size():
		if fleet[i] == null:
			continue
		fleet[i].invulnerable = true
		fleet[i].command_move(FLEET_ANCHOR + Vector2(-48 * i, 48 * i))
	EventBus.hud_notification.emit("The Spanish fleet has been sighted off Cebu!")


func _land_troops() -> void:
	for node in get_tree().get_nodes_in_group("faction_" + FACTION):
		var unit := node as Unit
		if unit != null:
			unit.invulnerable = false
	for i in int(GameSettings.difficulty_value("landing_soldados")):
		UnitSpawner.spawn(SOLDADO_SCENE, LANDING_ZONE + Vector2(-60 + 40 * i, 0), FACTION, true)
	for i in int(GameSettings.difficulty_value("landing_arcabuceros")):
		UnitSpawner.spawn(ARCABUCERO_SCENE, LANDING_ZONE + Vector2(-40 + 40 * i, 44), FACTION, true)
	EventBus.hud_notification.emit("The Spanish have landed on the southern beach!")
	EventBus.minimap_ping.emit(LANDING_ZONE)


func _spawn_frailes() -> void:
	var camp := _spanish_base()
	if camp == null:
		return
	for i in 2:
		UnitSpawner.spawn(FRAILE_SCENE, camp.global_position + Vector2(-40 + 80 * i, 90), FACTION, true)
	EventBus.hud_notification.emit("Spanish friars walk among the villages, preaching conversion.")


func _begin_assault() -> void:
	var camp := _spanish_base()
	var muster := camp.global_position + camp.gate_offset if camp != null else LANDING_ZONE
	magellan = UnitSpawner.spawn(MAGELLAN_SCENE, muster, FACTION, true)
	for i in 3:
		UnitSpawner.spawn(SOLDADO_SCENE, muster + Vector2(-50 + 40 * i, 40), FACTION, true)
	for i in 2:
		UnitSpawner.spawn(ARCABUCERO_SCENE, muster + Vector2(-30 + 50 * i, 80), FACTION, true)
	UnitSpawner.spawn(JINETE_SCENE, muster + Vector2(70, 40), FACTION, true)
	_order_combat_units_to_attack()
	EventBus.hud_notification.emit("Magellan leads the assault on the Kuta!")


func _go_desperate() -> void:
	if not _powder_warning_sent:
		_powder_warning_sent = true
		EventBus.powder_critically_low.emit()
	_order_combat_units_to_attack()
	EventBus.hud_notification.emit("Spain gambles everything on one final push!")


# --- Recurring actions ---

func _task_frailes() -> void:
	var neutral_villages: Array[DatuVillage] = []
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village != null and village.alignment == DatuVillage.Alignment.NEUTRAL:
			neutral_villages.append(village)
	if neutral_villages.is_empty():
		return
	for node in get_tree().get_nodes_in_group("faction_" + FACTION):
		var fraile := node as Fraile
		if fraile == null or fraile.state != Unit.State.IDLE:
			continue
		if fraile._village_in_reach() != null:
			continue  # already preaching
		var nearest: DatuVillage = null
		var nearest_distance := INF
		for village in neutral_villages:
			var distance := fraile.global_position.distance_to(village.global_position)
			if distance < nearest_distance:
				nearest = village
				nearest_distance = distance
		fraile.command_move(nearest.global_position + Vector2(50, 30))


## Waves escalate: +1 Soldado every 3rd wave, a Jinete every 2nd wave.
func _spawn_wave() -> void:
	var camp := _spanish_base()
	if camp == null:
		return
	_wave_number += 1
	var muster := camp.global_position + camp.gate_offset
	var target := _primary_target()
	var soldado_count := maxi(1, 2 + _wave_number / 3 + int(GameSettings.difficulty_value("wave_bonus")))
	for i in soldado_count:
		var soldado := UnitSpawner.spawn(SOLDADO_SCENE, muster + Vector2(-60 + 40 * i, 0), FACTION)
		if soldado != null and target != null:
			soldado.command_attack(target)
	var arcabucero := UnitSpawner.spawn(ARCABUCERO_SCENE, muster + Vector2(0, 44), FACTION)
	if arcabucero != null and target != null:
		arcabucero.command_attack(target)
	if _wave_number % 2 == 0:
		var jinete := UnitSpawner.spawn(JINETE_SCENE, muster + Vector2(60, 44), FACTION)
		if jinete != null and target != null:
			jinete.command_attack(target)


## Keep 2 friars preaching while the conversion effort is alive.
func _maintain_frailes() -> void:
	var live := 0
	for node in get_tree().get_nodes_in_group("faction_" + FACTION):
		if node is Fraile and node.state != Unit.State.DEAD:
			live += 1
	if live >= 2:
		return
	var base := _spanish_base()
	if base != null:
		UnitSpawner.spawn(FRAILE_SCENE, base.global_position + base.gate_offset, FACTION)


func _press_the_assault() -> void:
	var target := _primary_target()
	if target == null:
		return
	for node in get_tree().get_nodes_in_group("faction_" + FACTION):
		var unit := node as Unit
		if unit == null or unit is Fraile or unit.state == Unit.State.DEAD:
			continue
		if unit.state == Unit.State.IDLE:
			unit.command_attack(target)


func _order_combat_units_to_attack() -> void:
	var target := _primary_target()
	if target == null:
		return
	for node in get_tree().get_nodes_in_group("faction_" + FACTION):
		var unit := node as Unit
		if unit != null and not unit is Fraile and unit.state != Unit.State.DEAD:
			unit.command_attack(target)


func _on_powder_resupply() -> void:
	ResourceManager.add(FACTION, {"powder": POWDER_RESUPPLY_AMOUNT})
	_powder_warning_sent = false
	if state == State.DESPERATE:
		state = State.ASSAULT  # fresh powder restores the plan
		EventBus.spanish_state_changed.emit(State.keys()[state])
	EventBus.hud_notification.emit("A Spanish resupply ship slips through — powder replenished.")


# --- Helpers ---

func _spanish_base() -> Building:
	var camp := get_tree().current_scene.get_node_or_null("Buildings/SpanishCamp") as Building
	if camp != null and not camp.is_dead():
		return camp
	var beachhead := get_tree().current_scene.get_node_or_null("Buildings/SpanishBeachhead") as Building
	if beachhead != null and not beachhead.is_dead():
		return beachhead
	return null


func _primary_target() -> Node2D:
	var kuta := get_tree().get_first_node_in_group("kuta") as Building
	if kuta != null and not kuta.is_dead():
		return kuta
	for node in get_tree().get_nodes_in_group("buildings_mactan"):
		var building := node as Building
		if building != null and not building.is_dead():
			return building
	return get_tree().get_first_node_in_group("faction_mactan") as Node2D
