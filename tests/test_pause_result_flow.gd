extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	main._start_new_run()
	main.run.tick(3.0, 0.0, main.GameConfig.MAX_SPEED)
	main.run.tick(2.0, 500.0, main.GameConfig.MAX_SPEED)
	main._pause_run()
	assert(main.run.phase == main.RunState.Phase.PAUSED and main.get_node("CanvasLayer/PauseScreen").visible, "Pause must open a focused menu")
	assert(main.get_node("CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton").has_focus(), "Resume must be the safe default")

	main._request_restart()
	assert(main.get_node("CanvasLayer/ConfirmationScreen").visible, "Restart must require confirmation")
	main._cancel_confirmation()
	assert(main.get_node("CanvasLayer/PauseScreen").visible, "Cancel must preserve the paused run")
	main._request_restart()
	main._confirm_destructive_action()
	assert(main.run.phase == main.RunState.Phase.COUNTDOWN and is_zero_approx(main.run.distance), "Confirmed restart must reset into countdown")

	main.run.tick(3.0, 0.0, main.GameConfig.MAX_SPEED)
	main.run.tick(1.0, 600.0, main.GameConfig.MAX_SPEED)
	main.run.award_overtake(100)
	main.run.end()
	main._update_hud()
	var result_screen: Control = main.get_node("CanvasLayer/ResultScreen")
	var result_summary: Label = main.get_node("CanvasLayer/ResultScreen/Center/Card/Content/Summary")
	assert(result_screen.visible and result_summary.text.contains("燃油耗尽"), "Game over must show its ending reason")
	assert(result_summary.text.contains("超车  1") and result_summary.text.contains("距离"), "Settlement must show run statistics")

	main._replay_run()
	main.run.tick(3.0, 0.0, main.GameConfig.MAX_SPEED)
	main.run.mark_clear()
	main._update_hud()
	assert(result_screen.visible and result_summary.text.contains("抵达终点"), "Run clear must use a distinct settlement result")
	main._return_to_tour_map()
	var tour_map = main.get_node("CanvasLayer/TourMapScreen")
	assert(main.run.phase == main.RunState.Phase.TITLE and tour_map.visible, "Settlement must return to the tour map without restarting the program")
	assert(tour_map.controller.node_states()[1].unlocked, "Clearing the coast must unlock the harbor on return to the map")

	main._return_to_title()
	assert(main.run.phase == main.RunState.Phase.TITLE and main.get_node("CanvasLayer/TitleScreen").visible, "Settlement must return to title without restarting the program")

	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	await process_frame
	quit()
