extends SceneTree
## Procedural pixel-art asset generator (v2 — real sprites, not dots).
## Run with:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/gen_assets.gd
## Output is deterministic. Filenames are stable — scenes reference them.
##
## Humanoid units are 4-frame walk-cycle sheets (Sprite2D hframes = 4,
## frame 0 = idle). Ships/dummy are single frames (code-side bob).

const TILE := 64

# --- Palette ---
const OUTLINE := Color(0.10, 0.08, 0.06)
const SKIN_MACTAN := Color(0.72, 0.50, 0.32)
const SKIN_SPAIN := Color(0.86, 0.69, 0.56)
const WOOD := Color(0.45, 0.30, 0.15)
const WOOD_DARK := Color(0.33, 0.21, 0.10)
const METAL := Color(0.68, 0.71, 0.75)
const METAL_DARK := Color(0.38, 0.40, 0.45)
const GOLD := Color(0.90, 0.75, 0.20)
const STRAW := Color(0.80, 0.68, 0.40)
const STRAW_DARK := Color(0.66, 0.54, 0.28)
const CANVAS := Color(0.88, 0.84, 0.74)
const STONE := Color(0.62, 0.58, 0.50)
const BAMBOO := Color(0.72, 0.58, 0.35)

const TERRAIN_COLORS := {
	"land": Color(0.33, 0.55, 0.29),
	"jungle": Color(0.16, 0.35, 0.18),
	"beach": Color(0.85, 0.74, 0.48),
	"river": Color(0.30, 0.62, 0.65),
	"open_water": Color(0.10, 0.28, 0.43),
	"shallows": Color(0.25, 0.51, 0.60),
}
const TERRAIN_ORDER := ["land", "jungle", "beach", "river", "open_water", "shallows"]

## Humanoid figure specs. weapon: spear/pike/kris/bow/gun/staff/cross/crossbow
const FIGURES := {
	"unit_mactan": {"skin": SKIN_MACTAN, "cloth": Color(0.78, 0.30, 0.16), "weapon": "spear", "shield": true, "band": Color(0.92, 0.20, 0.15)},
	"unit_mamamana": {"skin": SKIN_MACTAN, "cloth": Color(0.85, 0.65, 0.20), "weapon": "bow", "band": Color(0.35, 0.22, 0.12)},
	"unit_juramentado": {"skin": SKIN_MACTAN, "cloth": Color(0.55, 0.10, 0.10), "weapon": "kris", "band": Color(0.85, 0.10, 0.10)},
	"unit_babaylan": {"skin": SKIN_MACTAN, "cloth": Color(0.80, 0.72, 0.90), "weapon": "staff", "robe": true},
	"unit_soldado": {"skin": SKIN_SPAIN, "cloth": Color(0.35, 0.37, 0.42), "weapon": "pike", "helmet": true},
	"unit_arcabucero": {"skin": SKIN_SPAIN, "cloth": Color(0.55, 0.58, 0.66), "weapon": "gun", "helmet": true},
	"unit_jinete": {"skin": SKIN_SPAIN, "cloth": Color(0.62, 0.48, 0.30), "weapon": "spear", "helmet": true, "mounted": true},
	"unit_fraile": {"skin": SKIN_SPAIN, "cloth": Color(0.52, 0.44, 0.34), "weapon": "cross", "robe": true, "hood": true},
	"hero_lapu_lapu": {"skin": SKIN_MACTAN, "cloth": Color(0.78, 0.30, 0.16), "weapon": "kris", "shield": true, "band": GOLD, "hero": true},
	"hero_sulayman": {"skin": SKIN_MACTAN, "cloth": Color(0.25, 0.40, 0.70), "weapon": "spear", "shield": true, "band": GOLD, "hero": true},
	"hero_magellan": {"skin": SKIN_SPAIN, "cloth": Color(0.30, 0.32, 0.38), "weapon": "crossbow", "helmet": true, "plume": true, "hero": true},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/gen")
	_gen_terrain_atlas()
	for name in FIGURES:
		_gen_figure_sheet(name, FIGURES[name])
	_gen_dummy()
	_gen_ships()
	_gen_buildings()
	_gen_villages()
	_gen_projectile_bits()
	_gen_selection_ring()
	_gen_portraits()
	print("gen_assets: done")
	quit()


# ============================== primitives ==============================

func _p(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _hl(img: Image, x: int, y: int, w: int, c: Color) -> void:
	for i in w:
		_p(img, x + i, y, c)


func _vl(img: Image, x: int, y: int, h: int, c: Color) -> void:
	for i in h:
		_p(img, x, y + i, c)


func _box(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for row in h:
		_hl(img, x, y + row, w, c)


func _dsc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - r)), mini(img.get_height(), int(cy + r) + 2)):
		for x in range(maxi(0, int(cx - r)), mini(img.get_width(), int(cx + r) + 2)):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) <= r:
				img.set_pixel(x, y, c)


func _save(img: Image, name: String) -> void:
	img.save_png("res://assets/gen/%s.png" % name)


# ============================== units ==============================

func _gen_figure_sheet(name: String, spec: Dictionary) -> void:
	var fw := 34 if spec.get("mounted", false) else 28
	var img := Image.create(fw * 4, 30, false, Image.FORMAT_RGBA8)
	for frame in 4:
		if spec.get("mounted", false):
			_draw_rider(img, frame * fw, frame, spec)
		else:
			_draw_humanoid(img, frame * fw + 1, frame, spec)
	_save(img, name)


func _draw_humanoid(img: Image, ox: int, frame: int, spec: Dictionary) -> void:
	var bounce: int = [0, -1, 0, -1][frame]
	var stride: int = [0, 2, 0, -2][frame]
	var cx := ox + 13
	var skin: Color = spec["skin"]
	var cloth: Color = spec["cloth"]
	var hero: bool = spec.get("hero", false)
	var y0 := bounce + (0 if hero else 2)  # heroes stand taller

	_hl(img, cx - 4, 27, 9, Color(0, 0, 0, 0.22))  # ground shadow

	if spec.get("robe", false):
		for i in 10:
			var half := 2 + int(i / 3.0)
			var shade := cloth if i % 3 != 0 else cloth.darkened(0.12)
			_hl(img, cx - half, 16 + i + y0, half * 2 + 1, shade)
	else:
		var leg := skin.darkened(0.18)
		_vl(img, cx - 2 - int(stride / 2.0), 19 + y0, 7, leg.darkened(0.15))
		_vl(img, cx + 1 + int(stride / 2.0), 19 + y0, 7, leg)
		_p(img, cx - 2 - int(stride / 2.0), 26 + y0, OUTLINE)
		_p(img, cx + 1 + int(stride / 2.0), 26 + y0, OUTLINE)

	# torso + arms
	_box(img, cx - 3, 12 + y0, 7, 7, cloth)
	_hl(img, cx - 3, 12 + y0, 7, cloth.lightened(0.18))
	if hero:
		_hl(img, cx - 3, 17 + y0, 7, GOLD)  # gold sash
	_vl(img, cx - 4, 13 + y0, 4, skin)
	_vl(img, cx + 3, 13 + y0, 4, skin)

	# head
	_dsc(img, cx + 0.5, 8.0 + y0, 3.4 if not hero else 3.7, skin)
	_p(img, cx + 2, 8 + y0, OUTLINE)  # eye

	# headgear
	if spec.get("helmet", false):
		_hl(img, cx - 3, 5 + y0, 8, METAL)
		_hl(img, cx - 4, 6 + y0, 10, METAL_DARK)  # morion brim
		if spec.get("plume", false):
			_vl(img, cx + 4, 1 + y0, 5, Color(0.82, 0.15, 0.15))
	elif spec.get("hood", false):
		_hl(img, cx - 3, 4 + y0, 8, cloth.darkened(0.2))
		_hl(img, cx - 3, 5 + y0, 8, cloth.darkened(0.1))
	else:
		_hl(img, cx - 3, 5 + y0, 8, spec.get("band", Color(0.95, 0.90, 0.80)))

	# shield (left)
	if spec.get("shield", false):
		_dsc(img, cx - 6.5, 15.0 + y0, 3.3, WOOD)
		_dsc(img, cx - 6.5, 15.0 + y0, 1.3, WOOD_DARK)

	# weapon (right)
	var wx := cx + 6
	match spec.get("weapon", ""):
		"spear":
			_vl(img, wx, 3 + y0, 19, WOOD)
			_vl(img, wx, 1 + y0, 3, METAL)
		"pike":
			_vl(img, wx, 0 + y0, 24, WOOD_DARK)
			_vl(img, wx, 0 + y0, 2, METAL)
		"kris":
			_vl(img, wx, 7 + y0, 7, METAL)
			_p(img, wx - 1, 9 + y0, METAL)  # wavy edge hint
			_p(img, wx + 1, 11 + y0, METAL)
			_p(img, wx, 14 + y0, GOLD)  # hilt
		"bow":
			for i in 13:
				_p(img, wx + int(2.6 * sin(PI * i / 12.0)), 4 + y0 + i, WOOD)
			_vl(img, wx, 4 + y0, 13, Color(0.92, 0.92, 0.86, 0.65))
		"gun":
			_hl(img, cx + 3, 12 + y0, 10, METAL_DARK)
			_hl(img, cx + 3, 13 + y0, 4, WOOD)  # stock
		"staff":
			_vl(img, wx, 3 + y0, 19, WOOD)
			_dsc(img, wx + 0.5, 3.5 + y0, 1.5, GOLD)
		"cross":
			_vl(img, wx, 8 + y0, 6, GOLD)
			_hl(img, wx - 1, 10 + y0, 3, GOLD)
		"crossbow":
			_hl(img, cx + 3, 12 + y0, 9, WOOD)
			_vl(img, cx + 9, 10 + y0, 5, METAL_DARK)


func _draw_rider(img: Image, ox: int, frame: int, spec: Dictionary) -> void:
	var stride: int = [0, 2, 0, -2][frame]
	var cx := ox + 16
	var horse := Color(0.48, 0.34, 0.20)
	_hl(img, cx - 8, 27, 17, Color(0, 0, 0, 0.22))
	# horse legs (alternate with stride)
	_vl(img, cx - 6 - int(stride / 2.0), 21, 6, horse.darkened(0.25))
	_vl(img, cx - 3 + int(stride / 2.0), 21, 6, horse.darkened(0.1))
	_vl(img, cx + 3 - int(stride / 2.0), 21, 6, horse.darkened(0.25))
	_vl(img, cx + 6 + int(stride / 2.0), 21, 6, horse.darkened(0.1))
	# horse body + neck + head
	_box(img, cx - 8, 16, 17, 5, horse)
	_hl(img, cx - 8, 16, 17, horse.lightened(0.15))
	_vl(img, cx + 8, 12, 5, horse)
	_box(img, cx + 8, 11, 4, 3, horse.darkened(0.1))
	_vl(img, cx - 9, 17, 4, horse.darkened(0.3))  # tail
	# rider
	var cloth: Color = spec["cloth"]
	var skin: Color = spec["skin"]
	_box(img, cx - 2, 9, 5, 7, cloth)
	_dsc(img, cx + 0.5, 6.0, 2.8, skin)
	_hl(img, cx - 2, 3, 6, METAL)
	_hl(img, cx - 3, 4, 8, METAL_DARK)
	# lance
	_vl(img, cx + 6, 0, 18, WOOD)
	_p(img, cx + 6, 0, METAL)


func _gen_dummy() -> void:
	var img := Image.create(24, 30, false, Image.FORMAT_RGBA8)
	_hl(img, 7, 27, 10, Color(0, 0, 0, 0.22))
	_vl(img, 11, 8, 19, WOOD)           # pole
	_hl(img, 4, 13, 16, WOOD_DARK)      # crossbar
	_box(img, 8, 12, 8, 9, STRAW)       # sack body
	_p(img, 10, 15, STRAW_DARK)
	_p(img, 13, 18, STRAW_DARK)
	_dsc(img, 12.0, 8.0, 3.4, STRAW)    # straw head
	_hl(img, 9, 5, 7, STRAW_DARK)
	_save(img, "unit_spain")


# ============================== ships ==============================

func _gen_ships() -> void:
	_save(_draw_karakoa(), "ship_karakoa")
	_save(_draw_balangay(), "ship_balangay")
	_save(_draw_galeon(), "ship_galeon")
	_save(_draw_bergantin(), "ship_bergantin")


func _hull(img: Image, x0: int, y0: int, w: int, rows: Array, base: Color) -> void:
	for i in rows.size():
		var margin: int = rows[i]
		var shade := base.lightened(0.12) if i == 0 else (base if i % 2 == 1 else base.darkened(0.10))
		_hl(img, x0 + margin, y0 + i, w - margin * 2, shade)


func _draw_karakoa() -> Image:
	var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	# outriggers
	_hl(img, 5, 20, 38, WOOD_DARK)
	for x in [10, 24, 38]:
		_p(img, x, 19, WOOD_DARK)
	_hull(img, 0, 13, 48, [7, 4, 2, 2, 4], WOOD)
	_vl(img, 4, 9, 4, WOOD.lightened(0.1))    # raised prow
	_vl(img, 43, 10, 3, WOOD.lightened(0.1))  # stern
	_vl(img, 24, 2, 11, WOOD_DARK)            # mast
	_box(img, 18, 3, 11, 7, STRAW)            # woven sail
	for i in 3:
		_vl(img, 20 + i * 3, 3, 7, STRAW_DARK)
	_p(img, 24, 1, Color(0.92, 0.20, 0.15))   # pennant
	return img


func _draw_balangay() -> Image:
	var img := Image.create(36, 16, false, Image.FORMAT_RGBA8)
	_hl(img, 4, 13, 28, WOOD_DARK)  # outrigger
	_hull(img, 0, 6, 36, [6, 3, 1, 2], Color(0.62, 0.44, 0.24))
	_vl(img, 6, 3, 3, Color(0.62, 0.44, 0.24))
	_vl(img, 29, 3, 3, Color(0.62, 0.44, 0.24))
	for x in [12, 18, 24]:  # paddles
		_p(img, x, 11, WOOD)
		_p(img, x + 1, 12, WOOD)
	return img


func _draw_galeon() -> Image:
	var img := Image.create(60, 30, false, Image.FORMAT_RGBA8)
	var hull := Color(0.32, 0.24, 0.16)
	_hull(img, 0, 18, 60, [5, 2, 1, 1, 2, 4], hull)
	for x in [12, 24, 36, 48]:  # gunports
		_p(img, x, 20, OUTLINE)
	_box(img, 46, 12, 10, 6, hull.lightened(0.18))  # stern castle
	_hl(img, 46, 12, 10, GOLD.darkened(0.2))
	for mast_x in [14, 29, 43]:
		_vl(img, mast_x, 2, 16, WOOD_DARK)
		_box(img, mast_x - 4, 4, 9, 7, CANVAS)
		_vl(img, mast_x - 4, 4, 7, CANVAS.darkened(0.12))
	_p(img, 29, 0, Color(0.85, 0.15, 0.12))
	_p(img, 30, 0, GOLD)
	return img


func _draw_bergantin() -> Image:
	var img := Image.create(44, 22, false, Image.FORMAT_RGBA8)
	var hull := Color(0.42, 0.32, 0.20)
	_hull(img, 0, 14, 44, [5, 2, 1, 3], hull)
	for mast_x in [14, 30]:
		_vl(img, mast_x, 3, 11, WOOD_DARK)
		for i in 8:  # lateen sail triangle
			_hl(img, mast_x + 1, 4 + i, int(i * 0.9) + 1, CANVAS)
	return img


# ============================== buildings ==============================

func _gen_buildings() -> void:
	_save(_draw_kuta(), "building_kuta")
	_save(_draw_nipa_hut(72, BAMBOO, false), "building_barracks")
	_save(_draw_shipyard(), "building_shipyard")
	_save(_draw_nipa_hut(64, Color(0.55, 0.42, 0.62), true), "building_shrine")
	_save(_draw_tents(80, 1), "building_beachhead")
	_save(_draw_tents(96, 2), "building_camp")
	_save(_draw_palace(), "building_palace")


func _draw_kuta() -> Image:
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1521
	_box(img, 8, 30, 80, 60, STONE)
	for i in 260:  # mottled coral stone
		_p(img, rng.randi_range(8, 87), rng.randi_range(30, 89), STONE.darkened(rng.randf_range(0.05, 0.2)))
	for i in 10:  # crenellations
		_box(img, 8 + i * 8, 24, 5, 6, STONE.lightened(0.08))
	_box(img, 40, 62, 16, 28, WOOD_DARK)  # gate
	_vl(img, 47, 62, 28, OUTLINE)
	for x in [8, 86]:  # corner posts
		_vl(img, x, 24, 66, WOOD_DARK)
	_vl(img, 48, 8, 16, WOOD)  # banner pole
	_box(img, 49, 8, 10, 6, Color(0.92, 0.20, 0.15))
	return img


func _draw_nipa_hut(s: int, accent: Color, shrine: bool) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var wall_y := int(s * 0.52)
	var wall_h := int(s * 0.30)
	# stilts
	for x in [int(s * 0.22), int(s * 0.78)]:
		_vl(img, x, wall_y + wall_h, int(s * 0.14), WOOD_DARK)
	# woven walls
	_box(img, int(s * 0.18), wall_y, int(s * 0.64), wall_h, BAMBOO)
	for i in int(s * 0.64 / 6.0):
		_vl(img, int(s * 0.18) + i * 6, wall_y, wall_h, BAMBOO.darkened(0.15))
	_box(img, int(s * 0.44), wall_y + int(wall_h * 0.3), int(s * 0.14), int(wall_h * 0.7), WOOD_DARK)  # door
	# thatch roof (widening rows)
	var ridge_y := int(s * 0.10) if shrine else int(s * 0.20)
	for i in wall_y - ridge_y:
		var half := 2 + int(float(i) / (wall_y - ridge_y) * s * 0.42)
		var shade := STRAW if i % 3 != 0 else STRAW_DARK
		_hl(img, int(s * 0.5) - half, ridge_y + i, half * 2, shade)
	if shrine:
		_vl(img, int(s * 0.5), ridge_y - 6, 7, GOLD)  # finial
		_box(img, int(s * 0.08), wall_y, 3, wall_h, accent)  # banner
		_box(img, int(s * 0.89), wall_y, 3, wall_h, accent)
	return img


func _draw_shipyard() -> Image:
	var s := 72
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	# plank platform
	_box(img, 4, 40, 64, 26, WOOD)
	for i in 6:
		_hl(img, 4, 40 + i * 4, 64, WOOD_DARK)
	for x in [8, 34, 62]:  # pilings
		_vl(img, x, 62, 8, WOOD_DARK)
	# hull skeleton under construction
	for i in 5:
		var rx := 14 + i * 10
		_vl(img, rx, 22 - absi(i - 2) * 3, 16 + absi(i - 2) * 3, Color(0.62, 0.44, 0.24))
	_hl(img, 12, 36, 48, Color(0.62, 0.44, 0.24).darkened(0.2))  # keel
	_vl(img, 60, 8, 32, WOOD_DARK)  # crane
	_hl(img, 50, 8, 11, WOOD_DARK)
	return img


func _draw_tents(s: int, tents: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	for t in tents:
		var cx := int(s * (0.32 + 0.38 * t))
		var base_y := int(s * 0.72)
		var height := int(s * 0.34)
		for i in height:  # canvas triangle
			var half := 1 + int(float(i) / height * s * 0.22)
			var shade := CANVAS if i % 4 != 0 else CANVAS.darkened(0.10)
			_hl(img, cx - half, base_y - height + i, half * 2, shade)
		_vl(img, cx, base_y - height - 4, 5, WOOD_DARK)
		_p(img, cx + 1, base_y - height - 4, Color(0.85, 0.15, 0.12))
		_vl(img, cx - 3, base_y - int(height * 0.4), int(height * 0.4), CANVAS.darkened(0.28))  # flap
	# crates
	for i in 3:
		var bx := int(s * 0.12) + i * 9
		_box(img, bx, int(s * 0.80), 7, 7, WOOD)
		_hl(img, bx, int(s * 0.83), 7, WOOD_DARK)
	if tents > 1:  # palisade for the main camp
		for i in int(s / 7.0):
			_vl(img, 3 + i * 7, int(s * 0.88), 9, WOOD_DARK)
			_p(img, 3 + i * 7, int(s * 0.88) - 1, WOOD)
	return img


func _draw_palace() -> Image:
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	_box(img, 14, 54, 68, 26, BAMBOO)
	for i in 11:
		_vl(img, 14 + i * 6, 54, 26, BAMBOO.darkened(0.15))
	for x in [20, 47, 74]:  # carved posts
		_vl(img, x, 54, 34, WOOD_DARK)
	# two-tier roof
	for i in 16:
		var half := 3 + int(float(i) / 16.0 * 26)
		_hl(img, 48 - half, 12 + i, half * 2, STRAW if i % 3 != 0 else STRAW_DARK)
	_hl(img, 48 - 30, 30, 60, GOLD.darkened(0.15))
	for i in 20:
		var half := 8 + int(float(i) / 20.0 * 34)
		_hl(img, 48 - half, 32 + i, half * 2, STRAW if i % 3 != 0 else STRAW_DARK)
	_vl(img, 48, 5, 8, GOLD)  # finial
	_box(img, 42, 66, 12, 14, WOOD_DARK)  # entry
	return img


func _gen_villages() -> void:
	for entry in [["village_neutral", Color(0.72, 0.72, 0.66)],
			["village_mactan", Color(0.85, 0.35, 0.20)],
			["village_spain", Color(0.83, 0.70, 0.20)]]:
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		_mini_hut(img, 6, 22, 20)
		_mini_hut(img, 26, 28, 16)
		_vl(img, 38, 4, 22, WOOD_DARK)  # flag pole
		_box(img, 39, 4, 9, 6, entry[1])
		_save(img, entry[0])


func _mini_hut(img: Image, x: int, y: int, w: int) -> void:
	var wall_h := int(w * 0.45)
	_box(img, x + 2, y + int(w * 0.4), w - 4, wall_h, BAMBOO)
	for i in int(w * 0.4 / 2.0):  # thatch
		var half := 1 + int(float(i) / (w * 0.4) * w * 0.55)
		_hl(img, x + int(w / 2.0) - half, y + int(w * 0.4) - int(w * 0.4) + i * 2, half * 2, STRAW if i % 2 == 0 else STRAW_DARK)


# ============================== terrain ==============================

func _gen_terrain_atlas() -> void:
	var img := Image.create(TILE * TERRAIN_ORDER.size(), TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1521
	for i in TERRAIN_ORDER.size():
		var terrain: String = TERRAIN_ORDER[i]
		var base: Color = TERRAIN_COLORS[terrain]
		var ox := i * TILE
		img.fill_rect(Rect2i(ox, 0, TILE, TILE), base)
		match terrain:
			"land":
				for t in 26:  # grass tufts
					var x := ox + rng.randi_range(1, TILE - 2)
					var y := rng.randi_range(2, TILE - 2)
					var g := base.lightened(rng.randf_range(0.06, 0.16)) if rng.randf() < 0.6 else base.darkened(0.12)
					_vl(img, x, y - 1, 2, g)
				for t in 6:
					_p(img, ox + rng.randi_range(2, TILE - 3), rng.randi_range(2, TILE - 3), Color(0.45, 0.38, 0.24))
			"jungle":
				for c in 4:  # palm canopies
					var cx := ox + rng.randi_range(10, TILE - 10)
					var cy := rng.randi_range(10, TILE - 12)
					_vl(img, cx, cy + 4, 6, WOOD_DARK)
					_dsc(img, cx + 0.5, cy, rng.randf_range(6.0, 8.5), base.darkened(0.22))
					_dsc(img, cx - 1.5, cy - 2, 3.5, base.lightened(0.10))
				for t in 20:
					_p(img, ox + rng.randi_range(1, TILE - 2), rng.randi_range(1, TILE - 2), base.darkened(rng.randf_range(0.05, 0.18)))
			"beach":
				for t in 40:
					_p(img, ox + rng.randi_range(1, TILE - 2), rng.randi_range(1, TILE - 2), base.darkened(rng.randf_range(0.04, 0.10)))
				for t in 8:
					_p(img, ox + rng.randi_range(2, TILE - 3), rng.randi_range(2, TILE - 3), Color(0.94, 0.90, 0.80))
			"river", "shallows":
				for t in 8:  # wave dashes
					var x := ox + rng.randi_range(2, TILE - 10)
					_hl(img, x, rng.randi_range(3, TILE - 4), rng.randi_range(4, 8), base.lightened(0.16))
				if terrain == "shallows":
					for t in 4:  # sandbar blotches
						_dsc(img, ox + rng.randf_range(8, TILE - 8), rng.randf_range(8, TILE - 8), rng.randf_range(2.5, 4.5), base.lightened(0.10))
			"open_water":
				for t in 6:
					var x := ox + rng.randi_range(2, TILE - 12)
					_hl(img, x, rng.randi_range(4, TILE - 5), rng.randi_range(5, 10), base.lightened(0.10))
	img.save_png("res://assets/gen/terrain_atlas.png")


# ============================== misc ==============================

func _gen_projectile_bits() -> void:
	var arrow := Image.create(14, 4, false, Image.FORMAT_RGBA8)
	arrow.fill_rect(Rect2i(0, 1, 11, 2), WOOD)
	arrow.fill_rect(Rect2i(0, 1, 3, 2), Color(0.85, 0.82, 0.72))  # fletching
	arrow.fill_rect(Rect2i(11, 1, 3, 2), METAL)
	_save(arrow, "arrow")
	var ball := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_dsc(ball, 5.0, 5.0, 4.0, Color(0.16, 0.16, 0.18))
	_dsc(ball, 3.8, 3.8, 1.4, Color(0.30, 0.30, 0.34))
	_save(ball, "lantaka_ball")


func _gen_selection_ring() -> void:
	var size := 36
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d >= 13.0 and d <= 15.5:
				img.set_pixel(x, y, Color(0.45, 0.95, 0.55, 0.9))
	_save(img, "selection_ring")


func _gen_portraits() -> void:
	for name: String in FIGURES:
		var slug: String = name.replace("unit_mactan", "mandirigma") \
			.replace("unit_", "").replace("hero_", "")
		if slug == "sulayman":
			slug = "rajah_sulayman"
		elif slug == "soldado":
			slug = "soldado_tercio"
		_save(_draw_portrait(FIGURES[name]), "portrait_" + slug)
	_save(_draw_ship_portrait(Color(0.50, 0.33, 0.18)), "portrait_karakoa")
	_save(_draw_ship_portrait(Color(0.62, 0.44, 0.24)), "portrait_balangay")
	_save(_draw_ship_portrait(Color(0.32, 0.24, 0.16)), "portrait_galeon")
	_save(_draw_ship_portrait(Color(0.42, 0.32, 0.20)), "portrait_bergantin")
	_save(_draw_portrait({"skin": STRAW, "cloth": STRAW_DARK}), "portrait_training_dummy")
	var structure := _frame_portrait(false)
	_mini_hut(structure, 10, 14, 28)
	_save(structure, "portrait_structure")


func _frame_portrait(hero: bool) -> Image:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:  # sky-to-sea gradient
		var t := float(y) / size
		_hl(img, 0, y, size, Color(0.16, 0.24, 0.32).lerp(Color(0.10, 0.20, 0.30), t))
	var border := GOLD if hero else Color(0.42, 0.44, 0.48)
	for i in size:
		for edge in 2:
			img.set_pixel(i, edge, border)
			img.set_pixel(i, size - 1 - edge, border)
			img.set_pixel(edge, i, border)
			img.set_pixel(size - 1 - edge, i, border)
	return img


func _draw_portrait(spec: Dictionary) -> Image:
	var img := _frame_portrait(spec.get("hero", false))
	var skin: Color = spec["skin"]
	var cloth: Color = spec["cloth"]
	# shoulders / bust
	_box(img, 12, 34, 24, 11, cloth)
	_hl(img, 12, 34, 24, cloth.lightened(0.15))
	if spec.get("hero", false):
		_hl(img, 12, 40, 24, GOLD)
	# head
	_dsc(img, 24.0, 22.0, 8.5, skin)
	_p(img, 21, 21, OUTLINE)
	_p(img, 27, 21, OUTLINE)
	_hl(img, 22, 26, 4, skin.darkened(0.25))  # mouth
	# headgear
	if spec.get("helmet", false):
		_box(img, 15, 11, 18, 4, METAL)
		_hl(img, 13, 15, 22, METAL_DARK)
		if spec.get("plume", false):
			_vl(img, 32, 5, 7, Color(0.82, 0.15, 0.15))
	elif spec.get("hood", false):
		_box(img, 15, 10, 18, 6, cloth.darkened(0.2))
	else:
		_box(img, 16, 12, 17, 3, spec.get("band", Color(0.95, 0.90, 0.80)))
	return img


func _draw_ship_portrait(hull: Color) -> Image:
	var img := _frame_portrait(false)
	_hl(img, 6, 34, 36, Color(0.20, 0.36, 0.46))  # waterline
	_hull(img, 6, 26, 36, [5, 2, 1, 2, 4, 6], hull)
	_vl(img, 24, 8, 18, WOOD_DARK)
	_box(img, 18, 10, 12, 9, CANVAS)
	_vl(img, 18, 10, 9, CANVAS.darkened(0.12))
	return img
