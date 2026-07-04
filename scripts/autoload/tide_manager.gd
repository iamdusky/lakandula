extends Node
## The tide cycle: LOW → RISING → HIGH → FALLING, 10 minutes each, starting
## HIGH (the fleet sails in on deep water). Tide state is public information.
##
## Low tide: galleons run aground (speed 0), the Karakoa rides free (×1.3),
## and the shallows open to land units (the "tide_shallows_region"
## NavigationRegion2D is enabled). High tide: galleons get a push (×1.1).
##
## Historical note: Magellan attacked at low tide — his galleons couldn't
## come close enough for their guns to matter. This is the key mechanic.

enum Phase { LOW, RISING, HIGH, FALLING }

const PHASE_DURATION := 600.0
const WARNING_LEAD := 60.0

const NEXT := {
	Phase.LOW: Phase.RISING,
	Phase.RISING: Phase.HIGH,
	Phase.HIGH: Phase.FALLING,
	Phase.FALLING: Phase.LOW,
}

const GALLEON_LOW_MULT := 0.0
const GALLEON_HIGH_MULT := 1.1
const KARAKOA_LOW_MULT := 1.3

var phase: Phase = Phase.HIGH

var _time_left := PHASE_DURATION
var _warned := false
var _active := false


func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)


func _process(delta: float) -> void:
	if not _active:
		return
	_time_left -= delta
	if not _warned and _time_left <= WARNING_LEAD:
		_warned = true
		EventBus.hud_notification.emit(
			"The tide turns in a minute — %s water ahead." % Phase.keys()[NEXT[phase]].to_lower())
	if _time_left <= 0.0:
		force_phase(NEXT[phase])


func time_left() -> float:
	return _time_left


func phase_name() -> String:
	return Phase.keys()[phase]


func save_state() -> Dictionary:
	return {"phase": phase, "time_left": _time_left}


func load_state(data: Dictionary) -> void:
	force_phase(int(data.get("phase", Phase.HIGH)) as Phase)
	_time_left = data.get("time_left", PHASE_DURATION)


## Units multiply their speed by this (tide is a global modifier, queried
## like TerrainManager).
func speed_multiplier(unit: Node) -> float:
	match phase:
		Phase.LOW:
			if unit.is_in_group("galleons"):
				return GALLEON_LOW_MULT
			if unit.is_in_group("karakoa"):
				return KARAKOA_LOW_MULT
		Phase.HIGH:
			if unit.is_in_group("galleons"):
				return GALLEON_HIGH_MULT
	return 1.0


## Also the test/debug hook — sets the phase immediately.
func force_phase(new_phase: Phase) -> void:
	var was_low := phase == Phase.LOW
	phase = new_phase
	_time_left = PHASE_DURATION
	_warned = false
	EventBus.tide_changed.emit(Phase.keys()[phase])
	_set_shallows_open(phase == Phase.LOW)
	if phase == Phase.LOW:
		EventBus.galleons_beached.emit()
		EventBus.hud_notification.emit("Low tide! The galleons run aground — the shallows lie open.")
	elif was_low:
		EventBus.galleons_freed.emit()
		EventBus.hud_notification.emit("The tide returns — the galleons float free.")


func _on_game_started() -> void:
	_active = true
	phase = Phase.HIGH
	_time_left = PHASE_DURATION
	_warned = false
	_set_shallows_open(false)


## The shallows region is always enabled for naval traffic (layer 2); low
## tide adds the land layer bit so land units can wade across.
func _set_shallows_open(open: bool) -> void:
	for node in get_tree().get_nodes_in_group("tide_shallows_region"):
		var region := node as NavigationRegion2D
		if region != null:
			region.navigation_layers = 3 if open else 2
