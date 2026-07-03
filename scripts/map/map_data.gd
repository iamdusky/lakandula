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

const TERRAIN_COLORS := {
	"land": Color(0.33, 0.55, 0.29),
	"jungle": Color(0.16, 0.35, 0.18),
	"beach": Color(0.85, 0.74, 0.48),
	"river": Color(0.30, 0.62, 0.65),
	"open_water": Color(0.10, 0.28, 0.43),
	"shallows": Color(0.25, 0.51, 0.60),
}


## One pixel per cell — used by the minimap and the briefing map preview.
static func build_preview_texture() -> ImageTexture:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in ROWS.size():
		var row := ROWS[y]
		for x in row.length():
			var terrain: String = LEGEND.get(row[x], "land")
			image.set_pixel(x, y, TERRAIN_COLORS.get(terrain, Color.BLACK))
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
