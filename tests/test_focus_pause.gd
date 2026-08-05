extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.run.start()
	main.engine_audio.play()
	main.collision_audio.play()
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(main.run.phase == main.RunState.Phase.PAUSED, "A running game must pause immediately when the window loses focus")
	assert(main.pause_screen.visible, "Focus pause must expose an explicit confirmation screen")
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		assert(not player.playing, "No gameplay audio may continue after focus loss")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(main.run.phase == main.RunState.Phase.PAUSED, "Returning focus must never resume driving automatically")
	main._resume_run()
	assert(main.run.phase == main.RunState.Phase.COUNTDOWN, "The player must explicitly confirm focus recovery")
	main._process(2.9)
	assert(main.run.phase == main.RunState.Phase.COUNTDOWN and is_zero_approx(main.run.distance), "Recovery countdown must keep gameplay frozen")
	main._process(0.1)
	assert(main.run.phase == main.RunState.Phase.RUNNING, "Recovery countdown must return to the interrupted run")

	main._return_to_title()
	main._start_new_run()
	assert(main.run.phase == main.RunState.Phase.COUNTDOWN, "A new run must begin with countdown")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(main.run.phase == main.RunState.Phase.PAUSED, "Losing focus during countdown must not start gameplay in the background")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(main.run.phase == main.RunState.Phase.PAUSED, "Countdown focus recovery must also require confirmation")

	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	quit()
