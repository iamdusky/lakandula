class_name Jinete
extends Unit
## Spanish light cavalry. The first strike against a fresh target lands with
## charge momentum (+80%). Horses are useless in jungle (see jinete.tres).

const CHARGE_MULT := 1.8

var _last_victim: Node2D = null


func _perform_attack(target: Node2D) -> void:
	var damage := current_damage()
	if target != _last_victim:
		damage *= CHARGE_MULT
		_last_victim = target
	target.take_damage(damage, self)
