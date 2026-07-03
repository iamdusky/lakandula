class_name Balangay
extends Unit
## Fast raider. Boarding: instead of striking a badly damaged enemy ship
## (below 30% health), the crew swarms aboard and captures it.

const BOARD_THRESHOLD := 0.3


func _ready() -> void:
	super()
	add_to_group("naval_units")


func _perform_attack(target: Node2D) -> void:
	if target.is_in_group("naval_units") \
			and target.health <= target.data.max_health * BOARD_THRESHOLD:
		target.capture(faction)
		EventBus.hud_notification.emit("Boarded! The %s is ours." % target.data.display_name)
		stop()
	else:
		super(target)
