class_name Galeon
extends Unit
## Spanish capital ship. Broadside shots splash and burn 2 Powder each.
## Cannot enter the river (terrain crawl in galeon.tres); beached entirely
## at low tide once TideManager arrives (Milestone 6 hooks the "galleons"
## group).

const BROADSIDE_SCENE := preload("res://scenes/projectiles/lantaka.tscn")
const POWDER_PER_SHOT := 2
const SPLASH_RADIUS := 60.0


func _ready() -> void:
	super()
	add_to_group("naval_units")
	add_to_group("galleons")


func _perform_attack(target: Node2D) -> void:
	if not ResourceManager.spend(faction, {"powder": POWDER_PER_SHOT}):
		return  # magazines empty
	Effects.cannon_smoke(global_position)
	_spawn_projectile(BROADSIDE_SCENE, target, current_damage(), {
		"speed": 320.0,
		"splash_radius": SPLASH_RADIUS,
	})
