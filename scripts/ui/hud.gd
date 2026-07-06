extends CanvasLayer
## Resource readout, day counter, and fading notifications.
## Purely reactive: listens to EventBus, never talks to managers directly
## (except reading initial state once at startup).

@onready var _rice: Label = $TopBar/RiceLabel
@onready var _copper: Label = $TopBar/CopperLabel
@onready var _honor: Label = $TopBar/HonorLabel
@onready var _allies: Label = $TopBar/AlliesLabel
@onready var _day: Label = $DayLabel
@onready var _note: Label = $NotificationLabel
@onready var _tide_label: Label = $TideBox/TideLabel
@onready var _tide_swatch: ColorRect = $TideBox/TideSwatch

## Filled in _ready from the terrain atlas so the swatch matches the art:
## LOW = exposed sand, HIGH = deep water, RISING/FALLING = shallows.
var _tide_colors := {}

var _note_tween: Tween


func _ready() -> void:
	_tide_colors = {
		"LOW": MapData.terrain_color("beach"),
		"RISING": MapData.terrain_color("shallows"),
		"HIGH": MapData.terrain_color("open_water"),
		"FALLING": MapData.terrain_color("shallows").darkened(0.15),
	}
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.hud_notification.connect(_on_notification)
	EventBus.powder_critically_low.connect(
		func() -> void: _on_notification("The Spanish powder reserves run critically low!"))
	_on_resources_changed("mactan", ResourceManager.resources["mactan"])
	_on_day_advanced(VictoryManager.current_day)
	_note.text = ""


func _process(_delta: float) -> void:
	var seconds := maxi(0, int(TideManager.time_left()))
	_tide_label.text = "Tide: %s — turns in %d:%02d" % [
		TideManager.phase_name(), seconds / 60, seconds % 60]
	_tide_swatch.color = _tide_colors.get(TideManager.phase_name(), Color.WHITE)


func _on_resources_changed(faction: String, res: Dictionary) -> void:
	if faction != "mactan":
		return
	_rice.text = "Rice %d" % res["rice"]
	_copper.text = "Copper %d" % res["copper"]
	_honor.text = "Honor %d" % res["honor"]
	_allies.text = "Allies %d" % res["allies"]


func _on_day_advanced(day: int) -> void:
	_day.text = "Day %d" % day


func _on_notification(text: String) -> void:
	_note.text = text
	_note.modulate.a = 1.0
	if _note_tween != null:
		_note_tween.kill()
	_note_tween = create_tween()
	_note_tween.tween_interval(3.0)
	_note_tween.tween_property(_note, "modulate:a", 0.0, 1.0)
