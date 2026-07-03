class_name Mamamana
extends Unit
## Archer. Every arrow carries poison. Lason: arrows apply double-strength
## poison for a short window.

const ARROW_SCENE := preload("res://scenes/projectiles/arrow.tscn")
const POISON_DPS := 2.0
const POISON_DURATION := 3.0
const LASON_DURATION := 6.0

var _lason_until_msec := 0


func _perform_attack(target: Node2D) -> void:
	var dps := POISON_DPS * TechTree.poison_multiplier(faction) * (2.0 if _lason_active() else 1.0)
	_spawn_projectile(ARROW_SCENE, target, current_damage(), {
		"poison_dps": dps,
		"poison_duration": POISON_DURATION,
	})


func use_ability() -> bool:
	if state == State.DEAD or _ability_timer > 0.0:
		return false
	_ability_timer = data.ability_cooldown
	_lason_until_msec = Time.get_ticks_msec() + int(LASON_DURATION * 1000)
	EventBus.hud_notification.emit("Lason! Arrows drip with concentrated venom.")
	return true


func _lason_active() -> bool:
	return Time.get_ticks_msec() < _lason_until_msec
