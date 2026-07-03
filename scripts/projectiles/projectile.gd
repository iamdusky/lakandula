class_name Projectile
extends Node2D
## Homing projectile. Flies toward its target (or the target's last known
## position if it dies mid-flight) and applies damage on arrival.
##
## setup() options:
##   speed: float           flight speed, px/s
##   splash_radius: float   damage all enemies within radius at impact
##   poison_dps: float      DoT applied to victims (bypasses armor)
##   poison_duration: float
##   ignore_armor: bool

var _target: Node2D = null
var _last_target_pos := Vector2.ZERO
var _damage := 0.0
var _source: Unit = null
var _source_faction := ""
var _speed := 480.0
var _splash_radius := 0.0
var _poison_dps := 0.0
var _poison_duration := 0.0
var _ignore_armor := false


func setup(target: Node2D, damage: float, source: Unit, options: Dictionary = {}) -> void:
	_target = target
	_last_target_pos = target.global_position
	_damage = damage
	_source = source
	_source_faction = source.faction if source != null else ""
	_speed = options.get("speed", _speed)
	_splash_radius = options.get("splash_radius", 0.0)
	_poison_dps = options.get("poison_dps", 0.0)
	_poison_duration = options.get("poison_duration", 0.0)
	_ignore_armor = options.get("ignore_armor", false)


func _physics_process(delta: float) -> void:
	if _target == null and _source == null:
		return  # not set up yet
	if is_instance_valid(_target) and not _target.is_dead():
		_last_target_pos = _target.global_position
	var to_target := _last_target_pos - global_position
	var step := _speed * delta
	if to_target.length() <= step:
		global_position = _last_target_pos
		_impact()
		return
	global_position += to_target.normalized() * step
	rotation = to_target.angle()


func _impact() -> void:
	if _splash_radius > 0.0:
		for node in get_tree().get_nodes_in_group("units"):
			var unit := node as Unit
			if unit != null and unit.faction != _source_faction \
					and unit.state != Unit.State.DEAD \
					and unit.global_position.distance_to(global_position) <= _splash_radius:
				_hit(unit)
	elif is_instance_valid(_target) and not _target.is_dead():
		_hit(_target)
	if TerrainManager.get_terrain_type(global_position) in ["open_water", "shallows", "river"]:
		Effects.water_splash(global_position)
	queue_free()


func _hit(victim: Node2D) -> void:
	var source := _source if is_instance_valid(_source) else null
	victim.take_damage(_damage, source, _ignore_armor)
	if _poison_dps > 0.0 and victim.has_method("apply_poison"):
		victim.apply_poison(_poison_dps, _poison_duration)
