extends Node
## One-shot particle effects + death ghosts. Pure visuals — safe to call
## from any script (references no game classes, so no circular loads).

const PARTICLE_TEXTURE := preload("res://assets/gen/lantaka_ball.png")


func death_burst(pos: Vector2, color := Color(0.85, 0.40, 0.20)) -> CPUParticles2D:
	return _burst(pos, color, 12, 70.0, 0.5, Vector2(0, 80))


func fire_burst(pos: Vector2) -> CPUParticles2D:
	_burst(pos, Color(0.45, 0.42, 0.4, 0.8), 16, 40.0, 1.1, Vector2(0, -50))  # smoke
	return _burst(pos, Color(1.0, 0.55, 0.15), 24, 100.0, 0.7, Vector2(0, -60))


func cannon_smoke(pos: Vector2) -> CPUParticles2D:
	return _burst(pos, Color(0.78, 0.78, 0.78, 0.7), 8, 35.0, 0.7, Vector2(0, -30))


func water_splash(pos: Vector2) -> CPUParticles2D:
	return _burst(pos, Color(0.60, 0.80, 0.90, 0.85), 10, 80.0, 0.4, Vector2(0, 160))


## Fading corpse sprite (units queue_free instantly on death).
func death_ghost(texture: Texture2D, pos: Vector2, flip_h: bool, tint := Color.WHITE) -> void:
	var scene := get_tree().current_scene
	if scene == null or texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.flip_h = flip_h
	ghost.modulate = tint
	scene.add_child(ghost)
	ghost.global_position = pos
	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.45)
	tween.tween_property(ghost, "scale", Vector2(0.6, 0.6), 0.45)
	tween.chain().tween_callback(ghost.queue_free)


func _burst(pos: Vector2, color: Color, amount: int, velocity: float,
		lifetime: float, gravity: Vector2) -> CPUParticles2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.texture = PARTICLE_TEXTURE
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = velocity * 0.5
	particles.initial_velocity_max = velocity
	particles.gravity = gravity
	particles.color = color
	scene.add_child(particles)
	particles.global_position = pos
	get_tree().create_timer(lifetime + 0.6).timeout.connect(particles.queue_free)
	return particles
