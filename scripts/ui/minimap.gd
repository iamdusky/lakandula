extends Control
## Minimap: terrain snapshot + faction dots, pings, and (while the diplomacy
## panel is open) Utang relationship lines. Click to pan the camera.

const MAP_ORIGIN := Vector2(-1280, -800)
const MAP_SIZE := Vector2(2560, 1600)
const REDRAW_INTERVAL := 0.15
const PING_LIFETIME := 3.0

const FACTION_COLORS := {
	"mactan": Color(0.40, 0.95, 0.45),
	"spain": Color(0.95, 0.30, 0.25),
	"cebu": Color(0.92, 0.80, 0.30),
}

const NEUTRAL_COLOR := Color(0.80, 0.80, 0.75)

var _pings: Array[Dictionary] = []
var _terrain_texture: ImageTexture
var _accumulator := 0.0

@onready var _diplomacy_panel: Control = get_node_or_null("../DiplomacyPanel")


func _ready() -> void:
	_terrain_texture = _build_terrain_texture()
	EventBus.minimap_ping.connect(_on_ping)


func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator >= REDRAW_INTERVAL:
		_accumulator = 0.0
		var now := Time.get_ticks_msec()
		_pings = _pings.filter(func(ping: Dictionary) -> bool: return ping["expires"] > now)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_pan_camera(click.position / size)


func _draw() -> void:
	draw_texture_rect(_terrain_texture, Rect2(Vector2.ZERO, size), false)

	# Utang relationship lines while the diplomacy panel is open.
	if _diplomacy_panel != null and _diplomacy_panel.visible:
		for line in _collect_utang_lines():
			draw_line(_to_map(line[0]), _to_map(line[1]), line[2], 1.5)

	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village == null:
			continue
		var color := NEUTRAL_COLOR
		match village.alignment:
			DatuVillage.Alignment.ALLIED_MACTAN:
				color = FACTION_COLORS["mactan"]
			DatuVillage.Alignment.ALLIED_SPAIN:
				color = FACTION_COLORS["spain"]
		draw_rect(Rect2(_to_map(village.global_position) - Vector2(2, 2), Vector2(4, 4)), color)

	for node in get_tree().get_nodes_in_group("buildings"):
		var building := node as Building
		if building == null or building.is_dead():
			continue
		draw_rect(Rect2(_to_map(building.global_position) - Vector2(2, 2), Vector2(4, 4)),
			FACTION_COLORS.get(building.faction, NEUTRAL_COLOR))

	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit.state == Unit.State.DEAD or not unit.visible:
			continue
		draw_rect(Rect2(_to_map(unit.global_position) - Vector2(1, 1), Vector2(2, 2)),
			FACTION_COLORS.get(unit.faction, NEUTRAL_COLOR))

	# Flashing pings.
	var now := Time.get_ticks_msec()
	for ping in _pings:
		if (now / 250) % 2 == 0:
			draw_arc(_to_map(ping["pos"]), 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.9), 1.5)

	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.9), false, 1.0)


func _collect_utang_lines() -> Array:
	var lines := []
	var kuta := get_tree().get_first_node_in_group("kuta") as Node2D
	if kuta == null:
		return lines
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village == null:
			continue
		var tokens := DiplomacyManager.get_tokens(village.datu_name, "mactan")
		var color := Color.TRANSPARENT
		match village.alignment:
			DatuVillage.Alignment.ALLIED_MACTAN:
				color = FACTION_COLORS["mactan"]
			DatuVillage.Alignment.ALLIED_SPAIN:
				color = FACTION_COLORS["spain"]
			DatuVillage.Alignment.NEUTRAL:
				if tokens > 0:
					color = NEUTRAL_COLOR
		if color != Color.TRANSPARENT:
			lines.append([kuta.global_position, village.global_position, Color(color, 0.65)])
	var palace := get_tree().current_scene.get_node_or_null("Buildings/HumabonPalace") as Node2D
	if palace != null:
		var humabon_color: Color = FACTION_COLORS["spain"]
		match DiplomacyManager.humabon_state:
			DiplomacyManager.HumabonState.NEUTRAL:
				humabon_color = NEUTRAL_COLOR
			DiplomacyManager.HumabonState.ALLIED_MACTAN:
				humabon_color = FACTION_COLORS["mactan"]
		lines.append([kuta.global_position, palace.global_position, Color(humabon_color, 0.65)])
	return lines


func _on_ping(world_pos: Vector2) -> void:
	_pings.append({"pos": world_pos, "expires": Time.get_ticks_msec() + int(PING_LIFETIME * 1000)})


func _pan_camera(ratio: Vector2) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.has_method("pan_to"):
		camera.pan_to(MAP_ORIGIN + ratio * MAP_SIZE)


func _to_map(world: Vector2) -> Vector2:
	return (world - MAP_ORIGIN) / MAP_SIZE * size


func _build_terrain_texture() -> ImageTexture:
	return MapData.build_preview_texture()
