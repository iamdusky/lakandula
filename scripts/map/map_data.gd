class_name MapData
extends RefCounted
## The Mactan strait map as ASCII. 40 x 25 cells, 64 px per cell.
## West edge: Cebu coast (unreachable across the strait until later milestones).
## Center-east: Mactan Island — west beach (Spanish landing zone), jungle east
## interior, a river from the inland spring to the south coast.
##
## Legend: ~ open_water   s shallows   b beach   . land   j jungle   r river

const WIDTH := 40
const HEIGHT := 25

const LEGEND := {
	"~": "open_water",
	"s": "shallows",
	"b": "beach",
	".": "land",
	"j": "jungle",
	"r": "river",
}

## Fallback only — the real palette is sampled from the terrain atlas so the
## minimap/preview/tide-swatch always match the shipped art (issue #2).
const TERRAIN_COLORS := {
	"land": Color(0.33, 0.55, 0.29),
	"jungle": Color(0.16, 0.35, 0.18),
	"beach": Color(0.85, 0.74, 0.48),
	"river": Color(0.30, 0.62, 0.65),
	"open_water": Color(0.10, 0.28, 0.43),
	"shallows": Color(0.25, 0.51, 0.60),
}

## Column order in assets/gen/terrain_atlas.png (matches MapBuilder.ATLAS_X).
const ATLAS_ORDER := ["land", "jungle", "beach", "river", "open_water", "shallows"]
const ATLAS_TILE := 64

static var _sampled_colors := {}


## Average tile color, sampled once from the atlas art.
static func terrain_color(terrain: String) -> Color:
	if _sampled_colors.is_empty():
		_sample_atlas_colors()
	return _sampled_colors.get(terrain, TERRAIN_COLORS.get(terrain, Color.BLACK))


static func _sample_atlas_colors() -> void:
	var texture := load("res://assets/gen/terrain_atlas.png") as Texture2D
	if texture == null:
		_sampled_colors = TERRAIN_COLORS.duplicate()
		return
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	for i in ATLAS_ORDER.size():
		var sum := Vector3.ZERO
		var count := 0
		for y in range(0, ATLAS_TILE, 2):
			for x in range(0, ATLAS_TILE, 2):
				var pixel := image.get_pixel(i * ATLAS_TILE + x, y)
				sum += Vector3(pixel.r, pixel.g, pixel.b)
				count += 1
		_sampled_colors[ATLAS_ORDER[i]] = Color(sum.x / count, sum.y / count, sum.z / count)


## One pixel per cell — used by the minimap and the briefing map preview.
static func build_preview_texture() -> ImageTexture:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in ROWS.size():
		var row := ROWS[y]
		for x in row.length():
			var terrain: String = LEGEND.get(row[x], "land")
			image.set_pixel(x, y, terrain_color(terrain))
	return ImageTexture.create_from_image(image)

const ROWS: Array[String] = [
	"jj.bs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"jj.bs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"jj.bs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"jj.bs~~~~~~~~ssssssssssssssssssssssss~~~",
	"jj.bs~~~~~~~~sbbbbbbbbbbbbbbbbbbbbbbs~~~",
	"jj.bs~~~~~~~~sb.........jjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.........jjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.........jjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.......r.jjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.......r.jjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.......r.jjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.......r.jjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.......r.jjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb........rjjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb........rjjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb........rjjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb........rjjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.........rjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sb.........rjjjjjjjjj.bs~~~",
	"jj.bs~~~~~~~~sbbbbbbbbbbrbbbbbbbbbbbs~~~",
	"jj.bs~~~~~~~~ssssssssssssssssssssssss~~~",
	"jj.bs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"jj.bs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"jj.bs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
	"jj.bs~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]
