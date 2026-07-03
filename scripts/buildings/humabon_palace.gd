class_name HumabonPalace
extends Building
## Cebu faction HQ across the strait. Untouchable early game (the strait is
## neutral ground); becomes attackable if Humabon is still Spain's ally past
## day 20. Milestone 4's flip mechanic can avert that permanently.

const ATTACKABLE_AFTER_DAY := 20

var attackable := false

var _flipped := false


func _ready() -> void:
	super()
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.humabon_flip_stage.connect(_on_humabon_flip_stage)


func _on_day_advanced(day: int) -> void:
	if _flipped or attackable or day <= ATTACKABLE_AFTER_DAY:
		return
	attackable = true
	EventBus.hud_notification.emit("Humabon clings to Spain — his palace lies open to attack.")


func _on_humabon_flip_stage(stage: String) -> void:
	if stage == "neutral" or stage == "allied":
		_flipped = true
		attackable = false


func take_damage(amount: float, source: Node = null, ignore_armor := false) -> void:
	if not attackable:
		return
	super(amount, source, ignore_armor)
