class_name Hero
extends Unit
## Hero base: pulsing passive aura + respawn instead of permadeath (design
## rule: Lapu-Lapu cannot permanently die until Milestone 7 wires the real
## loss condition — VictoryManager listens to EventBus.hero_died for that).

const RESPAWN_TIME := 20.0
const AURA_RADIUS := 180.0
const AURA_INTERVAL := 0.5

var _spawn_position := Vector2.ZERO
var _aura_accumulator := 0.0


func _ready() -> void:
	super()
	add_to_group("heroes")
	_spawn_position = global_position


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	_aura_accumulator += delta
	if _aura_accumulator >= AURA_INTERVAL:
		_aura_accumulator = 0.0
		_apply_aura()


## Override: grant aura effects to nearby allies.
func _apply_aura() -> void:
	pass


## Heroes don't queue_free on death — they hide and respawn at their
## original spawn point.
func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	Effects.death_burst(global_position, DEATH_COLORS.get(faction, Color.WHITE))
	visible = false
	set_selected(false)
	EventBus.unit_died.emit(self)
	EventBus.hero_died.emit(self)
	EventBus.hud_notification.emit("%s has fallen!" % data.display_name)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)


func _respawn() -> void:
	health = data.max_health
	global_position = _spawn_position
	state = State.IDLE
	attack_target = null
	poison_dps = 0.0
	_poison_timer = 0.0
	_stun_timer = 0.0
	visible = true
	_health_bar.queue_redraw()
	EventBus.hero_respawned.emit(self)
	EventBus.hud_notification.emit("%s returns to the fight!" % data.display_name)
