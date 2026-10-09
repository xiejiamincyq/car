extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	await process_frame
	var hud = main.race_hud
	_check(hud.has_node("RouteMap"), "race HUD exposes a left-side route minimap")
	if not hud.has_node("RouteMap"):
		await _finish(main)
		return
	var map = hud.get_node("RouteMap")
	for track in Tracks.all():
		main.run.configure_track(track)
		for dimensions in [Vector2i(1280,720), Vector2i(1920,1080)]:
			root.size = dimensions
			await process_frame
			await process_frame
			for language in ["zh","en"]:
				main._set_language_preference(language)
				for distance in [0.0, float(track.checkpoint_distances[0]), float(track.finish_distance) * 0.5, float(track.finish_distance)]:
					main.run.distance = distance
					main._update_hud()
					var state: Dictionary = map.presentation()
					_check(is_equal_approx(state.progress, distance / track.finish_distance), "minimap follows selected track distance")
					_check(state.checkpoints.size() == track.checkpoint_distances.size(), "every real checkpoint is mapped")
					_check(map.get_global_rect().end.x < dimensions.x * 0.5 - main.GameConfig.ROAD_HALF_WIDTH, "minimap never covers driving lanes")
					_check(map.get_global_rect().position.y >= 180 and map.get_global_rect().end.y < hud.get_node("Rows/Speed").get_global_rect().position.y - 90.0, "minimap stays between top status and bottom dial")
					_check(hud.get_global_rect().encloses(map.get_global_rect()), "minimap fits both viewport sizes")
					_check(map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "passive minimap does not intercept controls")
			var checkpoint: float = track.checkpoint_distances[0]
			var before: Array = main.CheckpointRenderer.markers(main.run.progression, checkpoint - 20.0, dimensions.y)
			var after: Array = main.CheckpointRenderer.markers(main.run.progression, checkpoint - 10.0, dimensions.y)
			_check(not before.is_empty() and not after.is_empty(), "checkpoint road stripe is visible before crossing")
			if not before.is_empty() and not after.is_empty():
				_check(is_equal_approx(after[0].y-before[0].y, 115.0), "road checkpoint has zero absolute world speed")
			main.run.distance = checkpoint
			var crossing: Array = main.CheckpointRenderer.markers(main.run.progression, checkpoint, dimensions.y)
			_check(not crossing.is_empty() and is_equal_approx(crossing[0].y, main.TrackGeometry.player_y(dimensions.y)), "checkpoint line reaches player exactly at reward crossing")
	main.run.distance = -10.0
	main._update_hud()
	_check(map.presentation().progress == 0.0, "route start clamps negative distance")
	main.run.distance = main.run.progression.finish_distance + 1000.0
	main._update_hud()
	_check(map.presentation().progress == 1.0, "route finish clamps overshoot")
	await _finish(main)

func _finish(main) -> void:
	var playbacks := AudioTeardown.capture(main)
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, playbacks), "audio resources released")
	for failure in failures: push_error("ROUTE_DISPLAY " + failure)
	print("ROUTE_DISPLAY failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_route_display.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
