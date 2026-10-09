extends SceneTree
## Synthetic rendered UI/road-marker fixture; not a human gameplay recording.
const MainScene = preload("res://scenes/main.tscn")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var output := "res://tmp/route-visual-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(output)
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	main.audio_director.shutdown()
	for dimensions in [Vector2i(1280,720), Vector2i(1920,1080)]:
		DisplayServer.window_set_size(dimensions)
		await process_frame
		await process_frame
		for track in Tracks.all():
			main.current_track = track
			main.run.configure_track(track)
			main.run.phase = main.RunState.Phase.RUNNING
			for state in ["approach","crossing","finish"]:
				main.run.distance = float(track.checkpoint_distances[0]) - 28.0 if state == "approach" else (float(track.checkpoint_distances[0]) if state == "crossing" else float(track.finish_distance)-18.0)
				main.drive.speed = 760.0
				main.run.coins = 47
				main.run.score = 12340
				main._update_hud()
				for name in ["menu_backdrop","overlay_shade","title_screen","countdown_screen","pause_screen","result_screen"]:
					main.get(name).hide()
				main.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var file := "%s/%s_%dx%d_%s.png" % [output,track.id,dimensions.x,dimensions.y,state]
				assert(root.get_texture().get_image().save_png(file) == OK)
				print("ROUTE_FRAME ",file)
	var playbacks := AudioTeardown.capture(main)
	main.queue_free()
	await process_frame
	assert(await AudioTeardown.wait_for_release(self,playbacks))
	print("ROUTE_VISUAL_COMPLETE ",ProjectSettings.globalize_path(output))
	quit()
