extends SceneTree
## Real rendered production warning fixture, not a human driving/FPS capture.
const MainScene = preload("res://scenes/main.tscn")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
func _init() -> void: call_deferred("_capture")
func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var folder := "res://tmp/fast-entry-visual-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	main.audio_director.shutdown()
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		DisplayServer.window_set_size(dimensions)
		await process_frame
		await process_frame
		for contrast in [false,true]:
			main._reset_run(611)
			main.run.start()
			main.drive.speed = 820.0
			main.high_contrast_enabled = contrast
			main.traffic.lane_events.enabled = false
			main.traffic.set_difficulty_stage(2)
			main.traffic._schedule_cursor = 2
			main.traffic._spawn_cooldown = 0.0
			main.traffic.tick(1.0/60.0,820.0,1)
			assert(main.traffic.fast_entry_warning().active and main.traffic.vehicles.is_empty())
			main._update_hud()
			for name in ["menu_backdrop","overlay_shade","title_screen","countdown_screen","pause_screen","result_screen"]:
				main.get(name).hide()
			main.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/warning-%dx%d-contrast%s.png" % [folder,dimensions.x,dimensions.y,contrast]
			assert(root.get_texture().get_image().save_png(path) == OK)
			print("FAST_ENTRY_FRAME ",path)
	var refs := AudioTeardown.capture(main)
	main.queue_free()
	await process_frame
	assert(await AudioTeardown.wait_for_release(self,refs))
	print("FAST_ENTRY_VISUAL_COMPLETE ",ProjectSettings.globalize_path(folder))
	quit()
