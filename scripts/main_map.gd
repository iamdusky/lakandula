extends Node2D
## MainMap root. Paints the map, builds navigation, registers terrain
## lookups, and starts the game clock.


func _ready() -> void:
	MapBuilder.build(
		$Terrain/TerrainLayer,
		$Terrain/WaterLayer,
		$NavRegionLand,
		$NavRegionNaval,
		$NavRegionShallows,
		$Buildings,
	)
	TerrainManager.register_terrain_map($Terrain/TerrainLayer, $Terrain/WaterLayer)
	VictoryManager.start_game()
	EventBus.hud_notification.emit("Day 1 — The Spanish fleet gathers beyond the strait.")

	if "--smoke-test" in OS.get_cmdline_user_args():
		var test: Node = load("res://tools/smoke_test.gd").new()
		add_child(test)
	if "--screenshot" in OS.get_cmdline_user_args():
		var capture: Node = load("res://tools/screenshot_capture.gd").new()
		add_child(capture)
