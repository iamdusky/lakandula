extends Node
## Fade-to-black scene router. Works while the tree is paused (game over)
## and unpauses before switching scenes.

const FADE_TIME := 0.3

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_rect)


func goto(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_in := create_tween()
	fade_in.tween_property(_rect, "color:a", 1.0, FADE_TIME)
	await fade_in.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	var fade_out := create_tween()
	fade_out.tween_property(_rect, "color:a", 0.0, FADE_TIME)
	await fade_out.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func reload() -> void:
	var current := get_tree().current_scene
	if current != null and not current.scene_file_path.is_empty():
		goto(current.scene_file_path)
