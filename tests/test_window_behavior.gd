extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	assert(InputMap.has_action("toggle_fullscreen"), "F11 fullscreen must have an InputMap action")
	var has_f11 := false
	for event in InputMap.action_get_events("toggle_fullscreen"):
		has_f11 = has_f11 or (event is InputEventKey and event.keycode == KEY_F11)
	assert(has_f11, "The fullscreen action must be bound to F11")
	assert(InputMap.has_action("pause_game"), "Manual pause must have an InputMap action")
	var pause_keys: Array[int] = []
	for event in InputMap.action_get_events("pause_game"):
		if event is InputEventKey:
			pause_keys.append(event.keycode)
	assert(pause_keys.has(KEY_SPACE), "The manual pause action must be bound to Space")
	assert(not pause_keys.has(KEY_P), "P must no longer trigger manual pause")
	assert(not pause_keys.has(KEY_ESCAPE), "Escape must no longer trigger manual pause")
	assert(InputMap.has_action("restart_run"), "The documented R restart shortcut must have an InputMap action")
	var has_restart_key := false
	for event in InputMap.action_get_events("restart_run"):
		has_restart_key = has_restart_key or (event is InputEventKey and event.keycode == KEY_R)
	assert(has_restart_key, "The restart action must be bound to R")
	main.run.start()
	assert(main._handle_restart_shortcut(), "A live run must accept the R restart shortcut")
	assert(main.confirmation_screen.visible and main.destructive_action == "restart", "R during a live run must use the existing restart confirmation flow")
	main._cancel_confirmation()
	var fullscreen_button: Button = main.get_node("CanvasLayer/SettingsScreen/Center/Card/Content/FullscreenButton")
	assert(not main.fullscreen_enabled and fullscreen_button.text.contains("窗口"), "The safe default must be windowed and visible in settings")
	main._toggle_fullscreen()
	assert(main.fullscreen_enabled and fullscreen_button.text.contains("全屏") and main.save_data.settings.fullscreen, "Settings fullscreen must update UI and persisted state together")
	main._toggle_fullscreen()
	assert(not main.fullscreen_enabled and not main.save_data.settings.fullscreen, "Fullscreen must toggle back to windowed mode")

	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		for screen_path in ["CanvasLayer/TitleScreen", "CanvasLayer/SettingsScreen", "CanvasLayer/ControlsScreen", "CanvasLayer/PauseScreen", "CanvasLayer/ResultScreen"]:
			var screen: Control = main.get_node(screen_path)
			var card: Control = screen.get_node("Center/Card")
			assert(screen.get_global_rect().encloses(card.get_global_rect()), "%s card must fit at %dx%d" % [screen_path, size.x, size.y])
	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	quit()
