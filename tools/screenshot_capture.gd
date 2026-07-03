extends Node
## Dev tool: run the game windowed for a moment, save a screenshot, quit.
##   Godot --path . -- --screenshot /absolute/out.png [--zoom 1.5]
## (Requires a real window — does not work with --headless.)

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "res://screenshot.png"
	var index := args.find("--screenshot")
	if index < 0:
		index = args.find("--screenshot-menu")
	if index >= 0 and index + 1 < args.size() and not args[index + 1].begins_with("--"):
		out_path = args[index + 1]
	var zoom_index := args.find("--zoom")
	if zoom_index >= 0 and zoom_index + 1 < args.size():
		var camera := get_viewport().get_camera_2d()
		if camera != null:
			var level := float(args[zoom_index + 1])
			camera.zoom = Vector2(level, level)
	await get_tree().create_timer(1.5).timeout
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_path)
	print("screenshot saved: %s" % out_path)
	get_tree().quit()
