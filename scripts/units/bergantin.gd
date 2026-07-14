class_name Bergantin
extends Unit
## Spanish scout ship. Fast, light guns (1 Powder per shot), and shallow
## enough draft to enter river approaches (full river speed in
## bergantin.tres, unlike the Galeon).

const SHOT_SCENE := preload("res://scenes/projectiles/musket_ball.tscn")
const POWDER_PER_SHOT := 1


func _ready() -> void:
	super()
	add_to_group("naval_units")
	add_to_group("powder_weapons")


func _perform_attack(target: Node2D) -> void:
	if not ResourceManager.spend(faction, {"powder": POWDER_PER_SHOT}):
		return
	Effects.cannon_smoke(global_position)
	_spawn_projectile(SHOT_SCENE, target, current_damage(), {"speed": 600.0})
