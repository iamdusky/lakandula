extends Camera2D
## RTS camera: WASD scroll, screen-edge scroll, mouse-wheel zoom.
## pan_to() is the hook for minimap clicks (Milestone 8).

@export var scroll_speed := 900.0
@export var edge_scroll_enabled := true
@export var edge_margin := 12
@export var zoom_step := 0.1
@export var zoom_min := 0.5
@export var zoom_max := 2.5
## World-space bounds the camera center may not leave.
@export var map_limits := Rect2(-2400, -1400, 4800, 2800)


func _process(delta: float) -> void:
	var dir := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if dir == Vector2.ZERO and edge_scroll_enabled:
		dir = _edge_scroll_direction()
	if dir != Vector2.ZERO:
		# Scroll slower when zoomed in so on-screen speed feels constant.
		position += dir * scroll_speed * GameSettings.scroll_speed_scale * delta / zoom.x
		position = _clamp_to_map(position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_set_zoom(zoom.x + zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_set_zoom(zoom.x - zoom_step)


func pan_to(world_pos: Vector2) -> void:
	position = _clamp_to_map(world_pos)


func _edge_scroll_direction() -> Vector2:
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()
	var size := viewport.get_visible_rect().size
	if not Rect2(Vector2.ZERO, size).has_point(mouse):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mouse.x <= edge_margin:
		dir.x -= 1.0
	elif mouse.x >= size.x - edge_margin:
		dir.x += 1.0
	if mouse.y <= edge_margin:
		dir.y -= 1.0
	elif mouse.y >= size.y - edge_margin:
		dir.y += 1.0
	return dir.normalized() if dir != Vector2.ZERO else dir


func _set_zoom(level: float) -> void:
	level = clampf(level, zoom_min, zoom_max)
	zoom = Vector2(level, level)


func _clamp_to_map(pos: Vector2) -> Vector2:
	return pos.clamp(map_limits.position, map_limits.end)
