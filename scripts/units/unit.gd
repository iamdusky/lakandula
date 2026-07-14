class_name Unit
extends CharacterBody2D
## Base class for all units: state machine, navigation, combat, status effects.
## Subclasses override _perform_attack() (ranged/special attacks),
## use_ability(), and _on_died().

enum State { IDLE, MOVING, ATTACKING, ABILITY, DEAD, ROUTING }

const CAPTURED_TINT := Color(1.0, 0.8, 0.6)
const DEATH_COLORS := {
	"mactan": Color(0.85, 0.40, 0.20),
	"spain": Color(0.60, 0.62, 0.66),
	"cebu": Color(0.92, 0.80, 0.30),
}

@export var data: UnitData
@export var faction := "mactan"

var health := 0.0
var state: State = State.IDLE
## A Unit or a Building — anything with take_damage() / is_dead().
var attack_target: Node2D = null
## Grace-period shield (Spanish fleet during SAIL_IN).
var invulnerable := false
var buff_speed := 1.0
var buff_damage := 1.0
var poison_dps := 0.0

## Auto-combat (M13): idle units acquire enemies within AGGRO_RADIUS and
## chase up to LEASH_RANGE from where they stood; attack-move sweeps.
const AGGRO_RADIUS := 260.0
const LEASH_RANGE := 320.0
const AGGRO_SCAN_INTERVAL := 0.4

## Morale (M14): units rout when a friendly hero dies nearby or when locally
## outnumbered 3:1 in combat. Hero-aura'd units hold against the odds.
const MORALE_SCAN_INTERVAL := 1.0
const MORALE_RADIUS := 200.0
const MORALE_OUTNUMBER_RATIO := 3
const HERO_DEATH_ROUT_RADIUS := 400.0
const ROUT_DURATION := 5.0
const HERO_DEATH_ROUT_DURATION := 6.0
const ROUT_FLEE_DISTANCE := 260.0
const ROUT_TINT := Color(1.0, 1.0, 1.0, 0.65)

var _attack_timer := 0.0
var _ability_timer := 0.0
var _poison_timer := 0.0
var _stun_timer := 0.0
var _auto_target := false
var _guard_position := Vector2.INF
var _attack_move_dest := Vector2.INF
## Kuta garrison (M18): while set, _process_moving() watches for arrival and
## hands the unit off to the building's garrison_unit().
var _garrison_target: Node2D = null
var _aggro_accumulator := 0.0
var _morale_accumulator := 0.0
var _rout_timer := 0.0
var _pre_rout_modulate := Color.WHITE
var _aura_attack_speed := 1.0
var _aura_damage := 1.0
var _aura_timer := 0.0
var _anim_time := 0.0
var _lunge := Vector2.ZERO

@onready var nav_agent: NavigationAgent2D = $NavAgent
@onready var _sprite: Sprite2D = $Sprite
@onready var _selection_ring: Sprite2D = $SelectionRing
@onready var _health_bar: Node2D = $HealthBar


func _ready() -> void:
	health = data.max_health
	add_to_group("units")
	add_to_group("faction_" + faction)
	_selection_ring.visible = false
	_aggro_accumulator = randf() * AGGRO_SCAN_INTERVAL  # spread scans
	_morale_accumulator = randf() * MORALE_SCAN_INTERVAL
	EventBus.hero_died.connect(_on_hero_died)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_ability_timer = maxf(0.0, _ability_timer - delta)
	_tick_status(delta)
	if state == State.DEAD:  # poison may have killed us
		return
	if _stun_timer > 0.0:
		velocity = Vector2.ZERO
		_animate(delta)
		return
	_aggro_accumulator += delta
	if _aggro_accumulator >= AGGRO_SCAN_INTERVAL:
		_aggro_accumulator = 0.0
		_aggro_scan()
	_morale_accumulator += delta
	if _morale_accumulator >= MORALE_SCAN_INTERVAL:
		_morale_accumulator = 0.0
		_morale_scan()
	match state:
		State.MOVING:
			_process_moving()
		State.ATTACKING:
			_process_attacking()
		State.ROUTING:
			_process_routing(delta)
	_animate(delta)


# --- Commands (issued by SelectionManager / AI) ---

func command_move(world_pos: Vector2) -> void:
	if state == State.DEAD or state == State.ROUTING:
		return
	attack_target = null
	_auto_target = false
	_attack_move_dest = Vector2.INF
	_guard_position = Vector2.INF
	_garrison_target = null
	nav_agent.target_position = world_pos
	state = State.MOVING


## Move to the building and garrison inside once in range.
func command_garrison(target: Node2D) -> void:
	if state == State.DEAD:
		return
	command_move(target.global_position)
	_garrison_target = target


func command_attack(target: Node2D) -> void:
	if state == State.DEAD or state == State.ROUTING or target == self:
		return
	attack_target = target
	_auto_target = false
	_attack_move_dest = Vector2.INF
	_guard_position = Vector2.INF
	_garrison_target = null
	state = State.ATTACKING


## Move toward world_pos, engaging any hostile that comes within aggro
## range on the way; resumes the sweep after each kill.
func command_attack_move(world_pos: Vector2) -> void:
	if state == State.DEAD or state == State.ROUTING:
		return
	attack_target = null
	_auto_target = false
	_guard_position = Vector2.INF
	_attack_move_dest = world_pos
	nav_agent.target_position = world_pos
	state = State.MOVING


func stop() -> void:
	if state == State.DEAD or state == State.ROUTING:
		return
	attack_target = null
	_auto_target = false
	_attack_move_dest = Vector2.INF
	_guard_position = Vector2.INF
	_garrison_target = null
	velocity = Vector2.ZERO
	state = State.IDLE


## Override in subclasses. Return true if the ability fired.
func use_ability() -> bool:
	return false


# --- Combat & status effects ---

func take_damage(amount: float, source: Unit = null, ignore_armor := false) -> void:
	if state == State.DEAD or invulnerable or amount <= 0.0:
		return
	var final := amount if ignore_armor else maxf(amount - data.armor, 1.0)
	# Impact sound cue fires BEFORE death processing so a killing blow's
	# game_over sting (victory/defeat) is the last sound played.
	EventBus.combat_hit.emit(self)
	_damage_health(final, source)
	# Retaliation: an idle unit turns on its attacker (even beyond aggro range).
	if state == State.IDLE and not data.passive and source != null \
			and is_instance_valid(source) and source.faction != faction \
			and not source.invulnerable:
		_acquire(source)


func heal(amount: float) -> void:
	if state == State.DEAD:
		return
	health = minf(data.max_health, health + amount)
	_health_bar.queue_redraw()


## Poison bypasses armor. Strongest active poison wins; duration refreshes.
func apply_poison(dps: float, duration: float) -> void:
	if state == State.DEAD:
		return
	poison_dps = maxf(poison_dps, dps)
	_poison_timer = maxf(_poison_timer, duration)


func stun(duration: float) -> void:
	if state == State.DEAD:
		return
	_stun_timer = maxf(_stun_timer, duration)


func is_stunned() -> bool:
	return _stun_timer > 0.0


func is_dead() -> bool:
	return state == State.DEAD


func get_max_health() -> float:
	return data.max_health


## Short-lived, hero-refreshed aura buff (attack speed / damage multipliers).
func grant_aura(attack_speed_mult: float, damage_mult: float, duration := 0.6) -> void:
	_aura_attack_speed = attack_speed_mult
	_aura_damage = damage_mult
	_aura_timer = duration


func apply_temp_buff(speed_mult: float, damage_mult: float, duration: float) -> void:
	buff_speed = speed_mult
	buff_damage = damage_mult
	get_tree().create_timer(duration).timeout.connect(_clear_buff)


## Boarding/defection: unit switches sides, keeping its stats.
func capture(new_faction: String) -> void:
	if new_faction == faction or state == State.DEAD:
		return
	remove_from_group("faction_" + faction)
	faction = new_faction
	add_to_group("faction_" + faction)
	stop()
	visible = true  # fog no longer manages this unit if it joined Mactan
	_sprite.modulate = CAPTURED_TINT
	EventBus.unit_captured.emit(self, new_faction)


func current_speed() -> float:
	return data.speed * _terrain_multiplier(data.terrain_speed) * buff_speed \
		* TideManager.speed_multiplier(self) * TechTree.speed_multiplier(self)


func current_damage() -> float:
	return data.damage * _terrain_multiplier(data.terrain_damage) * buff_damage \
		* _aura_damage * TechTree.damage_multiplier(self)


func set_selected(selected: bool) -> void:
	_selection_ring.visible = selected


# --- Internals ---

func _tick_status(delta: float) -> void:
	if _poison_timer > 0.0:
		_poison_timer -= delta
		_damage_health(poison_dps * delta, null)
		if _poison_timer <= 0.0:
			poison_dps = 0.0
	if _aura_timer > 0.0:
		_aura_timer -= delta
		if _aura_timer <= 0.0:
			_aura_attack_speed = 1.0
			_aura_damage = 1.0
	if _stun_timer > 0.0:
		_stun_timer = maxf(0.0, _stun_timer - delta)


func _process_moving() -> void:
	if _garrison_target != null:
		if not is_instance_valid(_garrison_target) or _garrison_target.is_dead():
			_garrison_target = null
		elif global_position.distance_to(_garrison_target.global_position) \
				< _garrison_target.attack_radius + 50.0:
			var g := _garrison_target
			_garrison_target = null
			g.garrison_unit(self)
			return
	if nav_agent.is_navigation_finished():
		stop()
		return
	_step_along_path()


func _process_attacking() -> void:
	if not is_instance_valid(attack_target) or attack_target.is_dead():
		if _attack_move_dest != Vector2.INF:
			command_attack_move(_attack_move_dest)  # resume the sweep
		else:
			stop()
		return
	# Auto-acquired targets have a leash — don't chase across the map.
	if _auto_target and _guard_position != Vector2.INF \
			and global_position.distance_to(_guard_position) > LEASH_RANGE:
		command_move(_guard_position)
		return
	var distance := global_position.distance_to(attack_target.global_position) \
		- _target_radius(attack_target)
	var reach := data.attack_range * TideManager.weapon_range_multiplier(self)
	if distance > reach:
		nav_agent.target_position = attack_target.global_position
		if not nav_agent.is_navigation_finished():
			_step_along_path()
	else:
		velocity = Vector2.ZERO
		if _attack_timer <= 0.0:
			_attack_timer = data.attack_interval / _aura_attack_speed
			_lunge = global_position.direction_to(attack_target.global_position) * 6.0
			_perform_attack(attack_target)


## Morale break: flee uncontrollably away from the threat for a few seconds.
func rout(duration := ROUT_DURATION, threat_position := Vector2.INF) -> void:
	if state == State.DEAD or state == State.ROUTING \
			or is_in_group("heroes") or data.speed <= 0.0:
		return
	if state != State.ROUTING:
		_pre_rout_modulate = _sprite.modulate
	attack_target = null
	_auto_target = false
	_attack_move_dest = Vector2.INF
	_guard_position = Vector2.INF
	state = State.ROUTING
	_rout_timer = duration
	var away := Vector2.RIGHT.rotated(randf() * TAU)
	if threat_position != Vector2.INF and threat_position != global_position:
		away = threat_position.direction_to(global_position)
	nav_agent.target_position = global_position + away * ROUT_FLEE_DISTANCE
	_sprite.modulate = _pre_rout_modulate * ROUT_TINT
	EventBus.unit_routed.emit(self)


## Rout ends on its timer only — a unit that reaches the map edge (or gets
## a spuriously "finished" path on the first frame) cowers in place instead
## of instantly recovering.
func _process_routing(delta: float) -> void:
	_rout_timer -= delta
	if _rout_timer <= 0.0:
		_sprite.modulate = _pre_rout_modulate
		state = State.IDLE
		velocity = Vector2.ZERO
		return
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		_step_along_path()


## Outnumbered 3:1 locally while fighting -> break. Hero auras steady nerves.
func _morale_scan() -> void:
	if state != State.ATTACKING or data.passive or is_in_group("heroes") \
			or _aura_timer > 0.0:
		return
	var allies := 0
	var enemies := 0
	var enemy_centroid := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit.state == State.DEAD or unit.data.passive:
			continue
		if global_position.distance_to(unit.global_position) > MORALE_RADIUS:
			continue
		if unit.faction == faction:
			allies += 1  # includes self
		else:
			enemies += 1
			enemy_centroid += unit.global_position
	if enemies >= MORALE_OUTNUMBER_RATIO * allies and enemies > 0:
		rout(ROUT_DURATION, enemy_centroid / enemies)


func _on_hero_died(hero: Node) -> void:
	if state == State.DEAD or hero == self:
		return
	if hero.faction == faction \
			and global_position.distance_to(hero.global_position) <= HERO_DEATH_ROUT_RADIUS:
		rout(HERO_DEATH_ROUT_DURATION, hero.global_position)


## Idle units and attack-movers look for hostiles to engage.
## Grace-period ceasefire: invulnerable units (Spanish fleet during SAIL_IN)
## don't open fire either.
func _aggro_scan() -> void:
	if data.passive or invulnerable or state == State.DEAD:
		return
	if state != State.IDLE \
			and not (state == State.MOVING and _attack_move_dest != Vector2.INF):
		return
	var enemy := _nearest_hostile(minf(data.sight_range, AGGRO_RADIUS))
	if enemy != null:
		_acquire(enemy)


func _acquire(target: Node2D) -> void:
	if state == State.IDLE:
		_guard_position = global_position
	attack_target = target
	_auto_target = true
	state = State.ATTACKING


## Nearest attackable enemy unit: not passive, not fog-hidden, not shielded.
func _nearest_hostile(radius: float) -> Node2D:
	var best: Unit = null
	var best_distance := radius
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit.faction == faction or unit.state == State.DEAD \
				or unit.data.passive or unit.invulnerable or not unit.visible:
			continue
		var distance := global_position.distance_to(unit.global_position)
		if distance < best_distance:
			best = unit
			best_distance = distance
	return best


## Default: melee hit. Ranged units override to spawn a projectile.
func _perform_attack(target: Node2D) -> void:
	target.take_damage(current_damage(), self)


## Buildings expose attack_radius so attackers measure range to their edge.
func _target_radius(target: Node2D) -> float:
	return target.attack_radius if "attack_radius" in target else 0.0


func _spawn_projectile(scene: PackedScene, target: Node2D, damage: float, options := {}) -> void:
	var projectile: Projectile = scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.setup(target, damage, self, options)


func _step_along_path() -> void:
	var next := nav_agent.get_next_path_position()
	velocity = global_position.direction_to(next) * current_speed()
	move_and_slide()
	if absf(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0.0


## Sheet-based walk cycle when the sprite has hframes (humanoids, frame 0 =
## idle); bob fallback for single-frame sprites (ships, dummy). Attack lunge
## applies to both.
func _animate(delta: float) -> void:
	_anim_time += delta
	_lunge = _lunge.move_toward(Vector2.ZERO, 40.0 * delta)
	if _sprite.hframes > 1:
		if velocity.length() > 5.0:
			_sprite.frame = int(_anim_time * 9.0) % _sprite.hframes
		else:
			_sprite.frame = 0
		_sprite.position = _lunge
		return
	var bob := 0.0
	if velocity.length() > 5.0:
		bob = absf(sin(_anim_time * 10.0)) * -3.0
	elif state == State.IDLE:
		bob = sin(_anim_time * 2.0) * 0.8
	_sprite.position = Vector2(0, bob) + _lunge


func _terrain_multiplier(table: Dictionary) -> float:
	if table.is_empty():
		return 1.0
	return table.get(TerrainManager.get_terrain_type(global_position), 1.0)


func _clear_buff() -> void:
	buff_speed = 1.0
	buff_damage = 1.0


func _damage_health(amount: float, _source: Unit) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_health_bar.queue_redraw()
	if health <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	Effects.death_burst(global_position, DEATH_COLORS.get(faction, Color.WHITE))
	Effects.death_ghost(_sprite.texture, global_position, _sprite.flip_h, _sprite.modulate)
	EventBus.unit_died.emit(self)
	_on_died()
	queue_free()


## Override for faction/hero-specific death handling.
func _on_died() -> void:
	pass
