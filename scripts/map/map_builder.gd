class_name MapBuilder
extends RefCounted
## Paints TerrainLayer/WaterLayer from MapData's ASCII rows and builds the
## land + naval navigation meshes from the painted cells. Cell quads share
## vertices, so the NavigationServer treats each mesh as one connected region.

const SOURCE_ID := 0
const ATLAS_X := {
	"land": 0, "jungle": 1, "beach": 2,
	"river": 3, "open_water": 4, "shallows": 5,
}
const WATER_TYPES := ["river", "open_water", "shallows"]


## nav_shallows: mesh over shallows cells only — always naval (layer 2);
## TideManager adds the land layer bit at low tide. The naval mesh excludes
## shallows cells so no two regions overlap. Pass null to keep shallows in
## the naval mesh instead.
## buildings_root: land cells under building footprints (their collision
## rects) are carved out of the land mesh so units path around structures.
static func build(
	terrain_layer: TileMapLayer,
	water_layer: TileMapLayer,
	nav_land: NavigationRegion2D,
	nav_naval: NavigationRegion2D,
	nav_shallows: NavigationRegion2D = null,
	buildings_root: Node = null,
) -> void:
	var land_cells: Array[Vector2i] = []
	var naval_cells: Array[Vector2i] = []
	var shallows_cells: Array[Vector2i] = []

	for y in MapData.ROWS.size():
		var row := MapData.ROWS[y]
		if row.length() != MapData.WIDTH:
			push_error("MapData row %d has length %d, expected %d" % [y, row.length(), MapData.WIDTH])
			continue
		for x in row.length():
			var terrain: String = MapData.LEGEND.get(row[x], "")
			if terrain.is_empty():
				push_error("MapData row %d col %d: unknown symbol '%s'" % [y, x, row[x]])
				continue
			var cell := Vector2i(x, y)
			var atlas := Vector2i(ATLAS_X[terrain], 0)
			if terrain in WATER_TYPES:
				water_layer.set_cell(cell, SOURCE_ID, atlas)
				if terrain == "shallows" and nav_shallows != null:
					shallows_cells.append(cell)
				else:
					naval_cells.append(cell)
			else:
				terrain_layer.set_cell(cell, SOURCE_ID, atlas)
				land_cells.append(cell)

	var tile: float = terrain_layer.tile_set.tile_size.x
	if buildings_root != null:
		land_cells = _carve_footprints(land_cells, buildings_root, terrain_layer.position, tile)
	nav_land.navigation_polygon = _cells_to_navmesh(land_cells, terrain_layer.position, tile)
	nav_naval.navigation_polygon = _cells_to_navmesh(naval_cells, water_layer.position, tile)
	if nav_shallows != null:
		nav_shallows.navigation_polygon = _cells_to_navmesh(shallows_cells, water_layer.position, tile)


## Drop cells whose center sits inside a building's collision rect.
static func _carve_footprints(
	cells: Array[Vector2i], buildings_root: Node, origin: Vector2, tile: float,
) -> Array[Vector2i]:
	var footprints: Array[Rect2] = []
	for building in buildings_root.get_children():
		var shape_node := building.get_node_or_null("CollisionShape") as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			var size: Vector2 = shape_node.shape.size
			footprints.append(Rect2(building.global_position - size * 0.5, size))
	if footprints.is_empty():
		return cells
	var kept: Array[Vector2i] = []
	for cell in cells:
		var center := origin + (Vector2(cell) + Vector2(0.5, 0.5)) * tile
		var blocked := false
		for footprint in footprints:
			if footprint.has_point(center):
				blocked = true
				break
		if not blocked:
			kept.append(cell)
	return kept


## One convex quad per cell; corners deduplicated so adjacent quads share
## edges and form a single walkable mesh.
static func _cells_to_navmesh(cells: Array[Vector2i], origin: Vector2, tile: float) -> NavigationPolygon:
	var nav := NavigationPolygon.new()
	var vertices := PackedVector2Array()
	var index_of := {}
	for cell in cells:
		var quad := PackedInt32Array()
		for corner in [cell, cell + Vector2i(1, 0), cell + Vector2i(1, 1), cell + Vector2i(0, 1)]:
			if not index_of.has(corner):
				index_of[corner] = vertices.size()
				vertices.append(origin + Vector2(corner) * tile)
			quad.append(index_of[corner])
		nav.add_polygon(quad)
	nav.vertices = vertices
	return nav
