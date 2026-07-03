extends Node
## Answers "what terrain type is at this world position?"
## Terrain types: land, jungle, beach, river, open_water, shallows.
## The map registers its tile layers here from _ready() (Milestone 1).

var _terrain_layer: TileMapLayer = null
var _water_layer: TileMapLayer = null


func register_terrain_map(terrain_layer: TileMapLayer, water_layer: TileMapLayer) -> void:
	_terrain_layer = terrain_layer
	_water_layer = water_layer


func get_terrain_type(world_pos: Vector2) -> String:
	# Water layer wins if it has a painted tile at this position.
	var type := _type_from_layer(_water_layer, world_pos)
	if type != "":
		return type
	type = _type_from_layer(_terrain_layer, world_pos)
	if type != "":
		return type
	return "land"


func _type_from_layer(layer: TileMapLayer, world_pos: Vector2) -> String:
	if layer == null:
		return ""
	var cell := layer.local_to_map(layer.to_local(world_pos))
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return ""
	var type = data.get_custom_data("terrain_type")
	return type if type is String else ""
