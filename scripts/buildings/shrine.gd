class_name ShrineBuilding
extends Building
## Trains Babaylan and passively generates Honor for its faction.

const HONOR_INTERVAL := 6.0
const HONOR_AMOUNT := 1


func _ready() -> void:
	super()
	var timer := Timer.new()
	timer.wait_time = HONOR_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_on_honor_tick)
	add_child(timer)


func _on_honor_tick() -> void:
	ResourceManager.add(faction, {"honor": HONOR_AMOUNT})
