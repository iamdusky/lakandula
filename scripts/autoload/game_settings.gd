extends Node
## Persistent settings + codex unlocks, stored in user://settings.cfg.
## Registered right after EventBus so every other autoload can read it at
## _ready. Setters save immediately and emit EventBus.settings_changed.

const PATH := "user://settings.cfg"

var music_volume := 0.8
var sfx_volume := 0.9
var scroll_speed_scale := 1.0
var health_bars_always := false
var fullscreen := false
var resolution := Vector2i(1600, 900)
var codex_unlocked: Array = []


func _ready() -> void:
	load_settings()
	apply_display.call_deferred()


func music_offset_db() -> float:
	return linear_to_db(clampf(music_volume, 0.001, 1.0))


func sfx_offset_db() -> float:
	return linear_to_db(clampf(sfx_volume, 0.001, 1.0))


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	save_settings()
	EventBus.settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_settings()
	EventBus.settings_changed.emit()


func set_scroll_speed_scale(value: float) -> void:
	scroll_speed_scale = clampf(value, 0.5, 2.0)
	save_settings()


func set_health_bars_always(value: bool) -> void:
	health_bars_always = value
	save_settings()
	EventBus.settings_changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()
	save_settings()


func set_resolution(value: Vector2i) -> void:
	resolution = value
	apply_display()
	save_settings()


func unlock_codex(id: String) -> void:
	if id in codex_unlocked:
		return
	codex_unlocked.append(id)
	save_settings()


func apply_display() -> void:
	var window := get_window()
	window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if not fullscreen:
		window.size = resolution


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("game", "scroll_speed_scale", scroll_speed_scale)
	config.set_value("game", "health_bars_always", health_bars_always)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution", resolution)
	config.set_value("codex", "unlocked", codex_unlocked)
	config.save(PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	music_volume = config.get_value("audio", "music_volume", music_volume)
	sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
	scroll_speed_scale = config.get_value("game", "scroll_speed_scale", scroll_speed_scale)
	health_bars_always = config.get_value("game", "health_bars_always", health_bars_always)
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	resolution = config.get_value("display", "resolution", resolution)
	codex_unlocked = config.get_value("codex", "unlocked", codex_unlocked)
