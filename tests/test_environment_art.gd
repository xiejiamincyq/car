extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const EnvironmentScroller = preload("res://scripts/environment_scroller.gd")
const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")

func _init() -> void:
	var all_sequence_paths := {}
	var all_content_hashes := {}
	for track in TrackCatalog.all():
		var left_paths: Array = track.environment_left_sequence_paths
		var right_paths: Array = track.environment_right_sequence_paths
		assert(left_paths.size() >= 4 and left_paths.size() == right_paths.size(), "%s must provide a multi-part paired scenery sequence" % track.id)
		var track_paths := {}
		for side_paths in [left_paths, right_paths]:
			for asset_path_value in side_paths:
				var asset_path := String(asset_path_value)
				assert(not track_paths.has(asset_path), "%s may not repeat a scenery image inside one race" % track.id)
				track_paths[asset_path] = true
				all_sequence_paths[asset_path] = true
				var content_hash := FileAccess.get_sha256(asset_path)
				assert(not all_content_hashes.has(content_hash), "%s must contain unique scenery content instead of copied files" % track.id)
				all_content_hashes[content_hash] = true
				var texture := load(asset_path) as Texture2D
				assert(texture != null and texture.get_size() == Vector2(256.0, 1024.0), "%s must use the sequence-strip canvas" % asset_path)
		for side_paths in [left_paths, right_paths]:
			for index in range(1, side_paths.size()):
				var previous := (load(String(side_paths[index - 1])) as Texture2D).get_image()
				var current := (load(String(side_paths[index])) as Texture2D).get_image()
				for x in range(256):
					assert(previous.get_pixel(x, 0).is_equal_approx(current.get_pixel(x, 1023)), "%s segment %d must join the preceding scenery without a seam" % [track.id, index])
		var distances := EnvironmentScroller.segment_distances(float(track.finish_distance), left_paths.size() - 1)
		var total_distance := 0.0
		for distance in distances:
			total_distance += distance
		assert(is_equal_approx(total_distance, float(track.finish_distance)), "%s scenery segments must add up to the exact race length" % track.id)
	assert(all_sequence_paths.size() >= 40, "Four tracks must use five distinct left/right scenery panels without repetition")

	var initial_sequence := EnvironmentScroller.sequence_tiles(0.0, 3200.0, 720.0, 1024.0, 5)
	var advanced_sequence := EnvironmentScroller.sequence_tiles(100.0, 3200.0, 720.0, 1024.0, 5)
	assert(initial_sequence.size() == 1 and advanced_sequence.size() == 2, "Ordered scenery must cover both the start and a moving transition")
	assert(float(advanced_sequence[0].y) > float(initial_sequence[0].y), "Roadside scenery must move down toward the player as the car advances")
	var visible_sequence := EnvironmentScroller.sequence_tiles(1200.0, 3200.0, 720.0, 1024.0, 5)
	assert(not visible_sequence.is_empty(), "A race-distance scenery sequence must cover the viewport")
	var top_edge := INF
	var bottom_edge := -INF
	var seen_indexes := {}
	for tile in visible_sequence:
		var tile_index := int(tile.index)
		assert(tile_index >= 0 and tile_index < 5, "Scenery sequence may only reference generated route panels")
		assert(not seen_indexes.has(tile_index), "A visible frame may not repeat the same scenery segment")
		seen_indexes[tile_index] = true
		top_edge = minf(top_edge, float(tile.y))
		bottom_edge = maxf(bottom_edge, float(tile.y) + 1024.0)
	assert(top_edge <= 0.0 and bottom_edge >= 720.0, "The ordered scenery sequence must cover the full viewport without a gap")
	var finish_sequence := EnvironmentScroller.sequence_tiles(3200.0, 3200.0, 720.0, 1024.0, 5)
	assert(finish_sequence.size() == 1 and int(finish_sequence[0].index) == 4 and is_zero_approx(float(finish_sequence[0].y)), "The last unique scenery panel must align with the exact finish line")

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var constants: Dictionary = main.get_script().get_script_constant_map()
	assert(constants.has("COAST_LEFT_TEXTURE") and constants.has("COAST_RIGHT_TEXTURE"), "Main must preload both coastal environment strips")
	main.queue_free()
	await process_frame
	quit()
