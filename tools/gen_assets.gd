extends SceneTree
## One-shot placeholder asset generator. Run with:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/gen_assets.gd
## Outputs land in assets/gen/. Re-run any time; output is deterministic.

const TILE := 64

const TERRAIN_COLORS := {
	"land": Color(0.33, 0.55, 0.29),
	"jungle": Color(0.16, 0.35, 0.18),
	"beach": Color(0.85, 0.74, 0.48),
	"river": Color(0.30, 0.62, 0.65),
	"open_water": Color(0.10, 0.28, 0.43),
	"shallows": Color(0.25, 0.51, 0.60),
}
const TERRAIN_ORDER := ["land", "jungle", "beach", "river", "open_water", "shallows"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/gen")
	_gen_terrain_atlas()
	_gen_unit_dot("unit_mactan", Color(0.78, 0.30, 0.16))
	_gen_unit_dot("unit_spain", Color(0.52, 0.54, 0.58))
	_gen_unit_dot("unit_mamamana", Color(0.85, 0.65, 0.20))
	_gen_unit_dot("unit_juramentado", Color(0.55, 0.10, 0.10))
	_gen_unit_dot("unit_babaylan", Color(0.80, 0.72, 0.90))
	_gen_unit_dot("unit_soldado", Color(0.35, 0.37, 0.42))
	_gen_unit_dot("unit_arcabucero", Color(0.55, 0.58, 0.66))
	_gen_unit_dot("unit_jinete", Color(0.62, 0.48, 0.30))
	_gen_unit_dot("unit_fraile", Color(0.92, 0.90, 0.82))
	_gen_hero_dot("hero_lapu_lapu", Color(0.78, 0.30, 0.16))
	_gen_hero_dot("hero_sulayman", Color(0.25, 0.40, 0.70))
	_gen_hero_dot("hero_magellan", Color(0.30, 0.32, 0.38))
	_gen_ship("ship_karakoa", 44, 18, Color(0.50, 0.33, 0.18))
	_gen_ship("ship_balangay", 32, 12, Color(0.62, 0.44, 0.24))
	_gen_ship("ship_galeon", 56, 22, Color(0.32, 0.24, 0.16))
	_gen_ship("ship_bergantin", 40, 14, Color(0.42, 0.32, 0.20))
	_gen_arrow()
	_gen_lantaka_ball()
	_gen_selection_ring()
	_gen_building("building_kuta", 96, Color(0.45, 0.30, 0.15))
	_gen_building("building_barracks", 72, Color(0.55, 0.38, 0.20))
	_gen_building("building_shipyard", 72, Color(0.35, 0.42, 0.50))
	_gen_building("building_shrine", 64, Color(0.55, 0.42, 0.62))
	_gen_building("building_beachhead", 80, Color(0.60, 0.58, 0.52))
	_gen_building("building_camp", 96, Color(0.40, 0.40, 0.44))
	_gen_building("building_palace", 96, Color(0.75, 0.62, 0.30))
	_gen_village("village_neutral", Color(0.72, 0.72, 0.66))
	_gen_village("village_mactan", Color(0.85, 0.35, 0.20))
	_gen_village("village_spain", Color(0.83, 0.70, 0.20))
	_gen_portraits()
	print("gen_assets: done")
	quit()


func _gen_terrain_atlas() -> void:
	var img := Image.create(TILE * TERRAIN_ORDER.size(), TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1521
	for i in TERRAIN_ORDER.size():
		var base: Color = TERRAIN_COLORS[TERRAIN_ORDER[i]]
		img.fill_rect(Rect2i(i * TILE, 0, TILE, TILE), base)
		for _s in 60:
			var x := i * TILE + rng.randi_range(0, TILE - 1)
			var y := rng.randi_range(0, TILE - 1)
			img.set_pixel(x, y, base.darkened(0.12))
	img.save_png("res://assets/gen/terrain_atlas.png")


func _gen_unit_dot(name: String, body: Color) -> void:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	_fill_circle(img, center, 11.0, body.darkened(0.4))
	_fill_circle(img, center, 9.0, body)
	img.save_png("res://assets/gen/%s.png" % name)


## Portraits keyed by display_name slug (SelectionInfo panel convention:
## lowercase, "-"/" " -> "_").
func _gen_portraits() -> void:
	var roster := {
		"mandirigma": Color(0.78, 0.30, 0.16),
		"mamamana": Color(0.85, 0.65, 0.20),
		"juramentado": Color(0.55, 0.10, 0.10),
		"babaylan": Color(0.80, 0.72, 0.90),
		"karakoa": Color(0.50, 0.33, 0.18),
		"balangay": Color(0.62, 0.44, 0.24),
		"lapu_lapu": Color(0.78, 0.30, 0.16),
		"rajah_sulayman": Color(0.25, 0.40, 0.70),
		"soldado_tercio": Color(0.35, 0.37, 0.42),
		"arcabucero": Color(0.55, 0.58, 0.66),
		"jinete": Color(0.62, 0.48, 0.30),
		"fraile": Color(0.92, 0.90, 0.82),
		"galeon": Color(0.32, 0.24, 0.16),
		"bergantin": Color(0.42, 0.32, 0.20),
		"magellan": Color(0.30, 0.32, 0.38),
		"training_dummy": Color(0.52, 0.54, 0.58),
	}
	var heroes := ["lapu_lapu", "rajah_sulayman", "magellan"]
	var ships := ["karakoa", "balangay", "galeon", "bergantin"]
	for name in roster:
		_gen_portrait(name, roster[name], name in heroes, name in ships)
	_gen_portrait("structure", Color(0.55, 0.40, 0.24), false, false, true)


func _gen_portrait(name: String, body: Color, hero: bool, ship: bool, structure := false) -> void:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.12, 0.15))
	var border := Color(0.90, 0.75, 0.20) if hero else Color(0.42, 0.44, 0.48)
	for i in size:
		for edge in 2:
			img.set_pixel(i, edge, border)
			img.set_pixel(i, size - 1 - edge, border)
			img.set_pixel(edge, i, border)
			img.set_pixel(size - 1 - edge, i, border)
	if structure:
		img.fill_rect(Rect2i(12, 16, 24, 22), body)
		img.fill_rect(Rect2i(9, 10, 30, 8), body.darkened(0.3))
	elif ship:
		img.fill_rect(Rect2i(8, 20, 32, 10), body)
		img.fill_rect(Rect2i(11, 22, 26, 3), body.lightened(0.25))
		img.fill_rect(Rect2i(22, 8, 2, 12), body.darkened(0.3))
	else:
		_fill_circle(img, Vector2(24, 34), 12.0, body)  # torso
		_fill_circle(img, Vector2(24, 17), 8.0, body.lightened(0.15))  # head
	img.save_png("res://assets/gen/portrait_%s.png" % name)


func _gen_building(name: String, size: int, wall: Color) -> void:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(wall.darkened(0.35))
	img.fill_rect(Rect2i(3, 3, size - 6, size - 6), wall)
	img.fill_rect(Rect2i(6, 6, size - 12, size / 4), wall.lightened(0.2))
	img.save_png("res://assets/gen/%s.png" % name)


func _gen_village(name: String, flag: Color) -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var hut := Color(0.50, 0.36, 0.20)
	img.fill_rect(Rect2i(12, 24, 24, 16), hut)
	img.fill_rect(Rect2i(10, 18, 28, 8), hut.darkened(0.3))
	img.fill_rect(Rect2i(34, 4, 2, 22), Color(0.25, 0.20, 0.15))
	img.fill_rect(Rect2i(36, 4, 10, 7), flag)
	img.save_png("res://assets/gen/%s.png" % name)


func _gen_hero_dot(name: String, body: Color) -> void:
	var size := 30
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	_fill_circle(img, center, 14.0, Color(0.90, 0.75, 0.20))  # gold ring
	_fill_circle(img, center, 11.0, body)
	img.save_png("res://assets/gen/%s.png" % name)


func _gen_ship(name: String, width: int, height: int, hull: Color) -> void:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var deck_h := height / 2
	img.fill_rect(Rect2i(2, (height - deck_h) / 2, width - 4, deck_h), hull)
	img.fill_rect(Rect2i(4, (height - deck_h) / 2 + 1, width - 8, 2), hull.lightened(0.25))
	# outriggers
	img.fill_rect(Rect2i(width / 5, 0, width * 3 / 5, 1), hull.darkened(0.3))
	img.fill_rect(Rect2i(width / 5, height - 1, width * 3 / 5, 1), hull.darkened(0.3))
	img.save_png("res://assets/gen/%s.png" % name)


func _gen_arrow() -> void:
	var img := Image.create(14, 4, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 1, 11, 2), Color(0.45, 0.30, 0.15))
	img.fill_rect(Rect2i(11, 1, 3, 2), Color(0.75, 0.75, 0.78))
	img.save_png("res://assets/gen/arrow.png")


func _gen_lantaka_ball() -> void:
	var size := 10
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	_fill_circle(img, Vector2(size, size) * 0.5, 4.0, Color(0.16, 0.16, 0.18))
	img.save_png("res://assets/gen/lantaka_ball.png")


func _gen_selection_ring() -> void:
	var size := 36
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d >= 13.0 and d <= 15.5:
				img.set_pixel(x, y, Color(0.45, 0.95, 0.55, 0.9))
	img.save_png("res://assets/gen/selection_ring.png")


func _fill_circle(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				img.set_pixel(x, y, color)
