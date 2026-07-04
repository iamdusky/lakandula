extends Node2D
## Minimal health bar drawn above a Unit or Building. Hidden at full health.
## The owner exposes `health` and `get_max_health()` and calls queue_redraw()
## on this node when damaged/healed.

const HEIGHT := 4.0

@export var width := 28.0

@onready var _owner: Node2D = get_parent()


func _ready() -> void:
	EventBus.settings_changed.connect(queue_redraw)


func _draw() -> void:
	var max_health: float = _owner.get_max_health()
	if _owner.health >= max_health and not GameSettings.health_bars_always:
		return
	var ratio: float = _owner.health / max_health
	draw_rect(Rect2(-width * 0.5, 0, width, HEIGHT), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-width * 0.5, 0, width * ratio, HEIGHT), Color(0.35, 0.9, 0.35))
