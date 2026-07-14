class_name Arcabucero
extends Unit
## Spanish arquebusier. Long reload, devastating shot — each shot burns
## 1 Powder (no powder = silent piece). Steps back after firing if the
## target is close.

const MUSKET_BALL_SCENE := preload("res://scenes/projectiles/musket_ball.tscn")
const POWDER_PER_SHOT := 1
const RETREAT_TIME := 0.9
const RETREAT_DISTANCE := 140.0

var _retreat_timer := 0.0


func _ready() -> void:
	super()
	add_to_group("powder_weapons")


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	if _retreat_timer > 0.0:
		_retreat_timer -= delta
		if is_instance_valid(attack_target):
			var away := attack_target.global_position.direction_to(global_position)
			global_position += away * data.speed * delta


func _perform_attack(target: Node2D) -> void:
	if not ResourceManager.spend(faction, {"powder": POWDER_PER_SHOT}):
		return  # out of powder
	Effects.cannon_smoke(global_position)
	_spawn_projectile(MUSKET_BALL_SCENE, target, current_damage(), {"speed": 700.0})
	if global_position.distance_to(target.global_position) < RETREAT_DISTANCE:
		_retreat_timer = RETREAT_TIME
