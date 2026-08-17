extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const EnvironmentScroller = preload("res://scripts/environment_scroller.gd")
const RoadsideRenderer = preload("res://scripts/roadside_renderer.gd")
const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")

func _init() -> void:
	for section_track in ["neon_coast", "freight_harbor", "storm_ridge"]:
		for section_index in range(5):
			assert(FileAccess.file_exists("res://art/source/environment_sequences/%s_sections/section_%02d.png" % [section_track, section_index]), "%s must use one full-resolution source image per route section" % section_track)
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
	assert(RoadsideRenderer.pixel_aligned_y(12.6) == 13.0, "Roadside panels must snap fractional scrolling to physical pixels")
	assert(RoadsideRenderer.visible_source_width(250.0, 256.0) == 250.0 and RoadsideRenderer.visible_source_width(320.0, 256.0) == 256.0, "Roadside panels must crop at native width instead of stretching beyond source resolution")

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
	var roadside_renderer := main.get_node_or_null("RoadsideRenderer")
	assert(roadside_renderer != null and roadside_renderer.z_index < 0, "Roadside scenery must render in an isolated layer behind the road")
	assert(roadside_renderer.material == null, "Roadside clarity must come from correctly sized source art instead of a compensating sharpening shader")
	var neon_track := TrackCatalog.get_by_id(&"neon_coast")
	var neon_luminance := _sampled_average_luminance(neon_track.environment_left_sequence_paths + neon_track.environment_right_sequence_paths)
	assert(neon_luminance >= 0.085, "Neon Coast roadside art must retain readable night-scene midtones")
	var freight_track := TrackCatalog.get_by_id(&"freight_harbor")
	var freight_luminance := _sampled_average_luminance(freight_track.environment_left_sequence_paths + freight_track.environment_right_sequence_paths)
	assert(freight_luminance >= 0.07, "Freight Harbor roadside art must retain readable industrial midtones")
	var storm_track := TrackCatalog.get_by_id(&"storm_ridge")
	var storm_luminance := _sampled_average_luminance(storm_track.environment_left_sequence_paths + storm_track.environment_right_sequence_paths)
	assert(storm_luminance >= 0.06, "Storm Ridge roadside art must retain readable wet-rock midtones")
	var constants: Dictionary = main.get_script().get_script_constant_map()
	assert(constants.has("COAST_LEFT_TEXTURE") and constants.has("COAST_RIGHT_TEXTURE"), "Main must preload both coastal environment strips")
	main.queue_free()
	await process_frame
	quit()

func _sampled_average_luminance(paths: Array) -> float:
	var total := 0.0
	var sample_count := 0
	for path_value in paths:
		var image := (load(String(path_value)) as Texture2D).get_image()
		for y in range(0, image.get_height(), 16):
			for x in range(0, image.get_width(), 8):
				var color := image.get_pixel(x, y)
				total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
				sample_count += 1
	return total / float(maxi(1, sample_count))
