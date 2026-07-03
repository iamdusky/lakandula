class_name FogOfWar
extends Sprite2D
## Fog of war: a low-res darkness texture stretched over the world.
## Mactan units (sight_range) and buildings punch holes; explored-but-unseen
## cells stay half-dark. Enemy UNITS are hidden under fog (buildings and
## villages remain visible landmarks). Updates every 0.3 s.
## Babaylan's Ritwal / Utang intel (EventBus.ritual_reveal) lifts the fog
## entirely for the duration.

const CELL := 32.0
const GRID_W := 80
const GRID_H := 50
const ORIGIN := Vector2(-1280, -800)
const UPDATE_INTERVAL := 0.3
const BUILDING_SIGHT := 280.0

const ALPHA_HIDDEN := 0.85
const ALPHA_EXPLORED := 0.5

var _visible_mask := PackedByteArray()
var _explored := PackedByteArray()
var _image: Image
var _texture: ImageTexture
var _accumulator := 0.0
var _reveal_until_msec := 0


func _ready() -> void:
	centered = false
	position = ORIGIN
	scale = Vector2(CELL, CELL)
	z_index = 50
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_visible_mask.resize(GRID_W * GRID_H)
	_explored.resize(GRID_W * GRID_H)
	_image = Image.create(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0.02, ALPHA_HIDDEN))
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture
	EventBus.ritual_reveal.connect(_on_ritual_reveal)
	_update_fog()


func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator >= UPDATE_INTERVAL:
		_accumulator = 0.0
		_update_fog()


func is_world_visible(world: Vector2) -> bool:
	if Time.get_ticks_msec() < _reveal_until_msec:
		return true
	var cell := Vector2i((world - ORIGIN) / CELL)
	if cell.x < 0 or cell.x >= GRID_W or cell.y < 0 or cell.y >= GRID_H:
		return false
	return _visible_mask[cell.y * GRID_W + cell.x] == 1


func _on_ritual_reveal(duration: float) -> void:
	_reveal_until_msec = Time.get_ticks_msec() + int(duration * 1000)
	_update_fog()


func _update_fog() -> void:
	var revealed := Time.get_ticks_msec() < _reveal_until_msec
	if revealed:
		_visible_mask.fill(1)
	else:
		_visible_mask.fill(0)
		for node in get_tree().get_nodes_in_group("faction_mactan"):
			var unit := node as Unit
			if unit != null and unit.state != Unit.State.DEAD:
				_stamp(unit.global_position, unit.data.sight_range)
		for node in get_tree().get_nodes_in_group("buildings_mactan"):
			var building := node as Building
			if building != null and not building.is_dead():
				_stamp(building.global_position, BUILDING_SIGHT)
	for i in GRID_W * GRID_H:
		var alpha := 0.0
		if _visible_mask[i] == 1:
			_explored[i] = 1
		elif _explored[i] == 1:
			alpha = ALPHA_EXPLORED
		else:
			alpha = ALPHA_HIDDEN
		_image.set_pixel(i % GRID_W, i / GRID_W, Color(0, 0, 0.02, alpha))
	_texture.update(_image)
	_update_enemy_visibility(revealed)


func _stamp(world: Vector2, sight: float) -> void:
	var center := (world - ORIGIN) / CELL
	var radius := sight / CELL
	var min_x := maxi(0, int(center.x - radius))
	var max_x := mini(GRID_W - 1, int(center.x + radius))
	var min_y := maxi(0, int(center.y - radius))
	var max_y := mini(GRID_H - 1, int(center.y + radius))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				_visible_mask[y * GRID_W + x] = 1


func _update_enemy_visibility(revealed: bool) -> void:
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit.faction == "mactan" or unit.state == Unit.State.DEAD:
			continue
		unit.visible = revealed or is_world_visible(unit.global_position)
