extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const EnvironmentScroller = preload("res://scripts/environment_scroller.gd")
const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")

func _init() -> void:
	for asset_path in ["res://assets/environment/coast_left.png", "res://assets/environment/coast_right.png"]:
		var texture := load(asset_path) as Texture2D
		assert(texture != null, "%s must import as a Texture2D" % asset_path)
		assert(texture.get_size() == Vector2(256.0, 1024.0), "%s must use the frozen scrolling-strip canvas" % asset_path)
	var track_paths := {}
	for track in TrackCatalog.all():
		for asset_path in [String(track.environment_left_path), String(track.environment_right_path), String(track.environment_left_alt_path), String(track.environment_right_alt_path)]:
			track_paths[asset_path] = true
			var texture := load(asset_path) as Texture2D
			assert(texture != null and texture.get_size() == Vector2(256.0, 1024.0), "%s must use the frozen scrolling-strip canvas" % asset_path)
			var image := texture.get_image()
			for x in range(0, 256, 32):
				assert(image.get_pixel(x, 0).is_equal_approx(image.get_pixel(x, 1023)), "%s must join cleanly across its vertical loop" % asset_path)
	assert(track_paths.size() == 16, "Four tracks must expose paired base and alternate environment strips")

	var positions := EnvironmentScroller.tile_positions(1300.0, 720.0, 1024.0)
	assert(not positions.is_empty(), "Environment scrolling must draw at least one strip")
	assert(positions[0] <= 0.0, "The first environment strip must begin above or at the viewport")
	assert(positions[-1] + 1024.0 >= 720.0, "The last environment strip must cover the viewport bottom")
	for index in range(1, positions.size()):
		assert(is_equal_approx(positions[index] - positions[index - 1], 1024.0), "Environment strips must meet without a gap")

	var initial_positions := EnvironmentScroller.tile_positions(0.0, 720.0, 1024.0)
	var advanced_positions := EnvironmentScroller.tile_positions(100.0, 720.0, 1024.0)
	assert(not initial_positions.is_empty() and not advanced_positions.is_empty(), "Environment direction check needs visible strips")
	assert(is_equal_approx(advanced_positions[-1] - initial_positions[-1], 100.0), "Roadside scenery must move down toward the player as the car advances")
	var seen_variants := {}
	for tile_index in range(16):
		var variant: int = EnvironmentScroller.variant_index(tile_index, 731, 2)
		seen_variants[variant] = true
		assert(variant == EnvironmentScroller.variant_index(tile_index, 731, 2), "Background variation must be deterministic for a fixed run seed")
	assert(seen_variants.size() == 2, "Long runs must alternate between more than one background texture variant")

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var constants: Dictionary = main.get_script().get_script_constant_map()
	assert(constants.has("COAST_LEFT_TEXTURE") and constants.has("COAST_RIGHT_TEXTURE"), "Main must preload both coastal environment strips")
	main.queue_free()
	await process_frame
	quit()
