extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const EnvironmentScroller = preload("res://scripts/environment_scroller.gd")

func _init() -> void:
	for asset_path in ["res://assets/environment/coast_left.png", "res://assets/environment/coast_right.png"]:
		var texture := load(asset_path) as Texture2D
		assert(texture != null, "%s must import as a Texture2D" % asset_path)
		assert(texture.get_size() == Vector2(256.0, 1024.0), "%s must use the frozen scrolling-strip canvas" % asset_path)

	var positions := EnvironmentScroller.tile_positions(1300.0, 720.0, 1024.0)
	assert(not positions.is_empty(), "Environment scrolling must draw at least one strip")
	assert(positions[0] <= 0.0, "The first environment strip must begin above or at the viewport")
	assert(positions[-1] + 1024.0 >= 720.0, "The last environment strip must cover the viewport bottom")
	for index in range(1, positions.size()):
		assert(is_equal_approx(positions[index] - positions[index - 1], 1024.0), "Environment strips must meet without a gap")

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var constants: Dictionary = main.get_script().get_script_constant_map()
	assert(constants.has("COAST_LEFT_TEXTURE") and constants.has("COAST_RIGHT_TEXTURE"), "Main must preload both coastal environment strips")
	main.queue_free()
	await process_frame
	quit()
