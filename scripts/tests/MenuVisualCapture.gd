extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 5:
		push_error("Usage: -- <title|tour|garage|settings|controls|pause|confirm|clear|failed> <output.png> <width> <height> <zh|en>")
		quit(2)
		return
	DisplayServer.window_set_size(Vector2i(int(args[2]), int(args[3])))
	await process_frame
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	main._set_language_preference(args[4])
	match args[0]:
		"tour": main._open_tour_map()
		"garage":
			main._open_tour_map()
			main._open_vehicle_select()
		"settings": main._show_settings()
		"controls": main._show_controls()
		"pause", "confirm", "clear", "failed":
			main.title_screen.hide()
			main.run.phase = main.RunState.Phase.RUNNING
			main.run.distance = 1800
			main._update_hud()
			if args[0] in ["pause", "confirm"]:
				main._pause_run()
				if args[0] == "confirm": main._request_restart()
			else:
				main.run.phase = main.RunState.Phase.RUN_CLEAR if args[0] == "clear" else main.RunState.Phase.GAME_OVER
				main.run.elapsed_seconds = 60.0
				main.run.score = 24800
				if args[0] == "clear": main.run.distance = main.run.progression.finish_distance
				main.run.overtakes = 12
				main.run.coins = 30
				main.run.collisions = 2
				main.result_persisted = false
				main._persist_result_once()
				main._update_hud()
				main._update_result_labels()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(args[1])
	if error != OK:
		push_error("Unable to save menu capture: %s" % error_string(error))
		quit(3)
		return
	print("CAPTURED menu %s %s -> %s" % [args[0], args[4], args[1]])
	main.queue_free()
	await process_frame
	quit()
