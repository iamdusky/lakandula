class_name Juramentado
extends Unit
## Elite oath-sworn berserker. Costs Honor, not Rice. Matay: for a short
## window every strike ignores armor entirely.

const MATAY_DURATION := 5.0

var _matay_until_msec := 0


func _perform_attack(target: Node2D) -> void:
	target.take_damage(current_damage(), self, _matay_active())


func use_ability() -> bool:
	if state == State.DEAD or _ability_timer > 0.0:
		return false
	_ability_timer = data.ability_cooldown
	_matay_until_msec = Time.get_ticks_msec() + int(MATAY_DURATION * 1000)
	EventBus.hud_notification.emit("Matay! The oath-sworn strikes past steel and armor.")
	return true


func _matay_active() -> bool:
	return Time.get_ticks_msec() < _matay_until_msec
