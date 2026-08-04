extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	var title_screen: Control = main.get_node("CanvasLayer/TitleScreen")
	var start_button: Button = main.get_node("CanvasLayer/TitleScreen/Center/Card/Content/StartButton")
	assert(title_screen.visible and start_button.has_focus(), "The game must open on a keyboard-focused title screen")
	assert(main.get_node("CanvasLayer/TitleScreen/Center/Card/Content/Goal").text.contains("燃油"), "The title must explain the run objective")

	main._show_settings()
	assert(main.get_node("CanvasLayer/SettingsScreen").visible and not title_screen.visible, "Settings must be reachable from title")
	main._close_submenu()
	assert(title_screen.visible and start_button.has_focus(), "Cancel must return to the title focus target")

	main._show_controls()
	assert(main.get_node("CanvasLayer/ControlsScreen").visible, "Keyboard controls must be available in-game")
	main._close_submenu()

	main._start_new_run()
	assert(main.run.phase == main.RunState.Phase.COUNTDOWN, "Start must enter the safety countdown")
	assert(main.get_node("CanvasLayer/CountdownScreen").visible and not title_screen.visible, "Countdown must replace the title")
	main._process(3.0)
	assert(main.run.phase == main.RunState.Phase.RUNNING, "Countdown must enter gameplay")
	assert(main.get_node("CanvasLayer/RaceHUD").visible and not main.get_node("CanvasLayer/CountdownScreen").visible, "The formal HUD must appear when driving")

	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	await process_frame
	quit()
