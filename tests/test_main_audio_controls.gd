extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	assert(InputMap.has_action("toggle_mute"), "The M mute action must be registered")
	main.run.start()
	main._play_effect(main.collision_audio)
	main._play_effect(main.pickup_audio)
	main.engine_audio.play()
	main._toggle_audio_mute()
	assert(main.audio_muted, "M must toggle mute")
	assert(not main.collision_audio.playing and not main.pickup_audio.playing and not main.engine_audio.playing, "M must stop all active audio immediately")
	main.audio_muted = false
	main.run.start()
	main.engine_audio.play()
	main.run.toggle_pause()
	main._process(0.0)
	assert(not main.engine_audio.playing, "Pause must stop run audio")
	main.run.toggle_pause()
	main.run.tick(3.0, 0.0, main.GameConfig.MAX_SPEED)
	main.engine_audio.play()
	main.run.elapsed_seconds = 30.0
	main.run.fuel = 0.0
	main._process(0.1)
	assert(main.run.phase == main.RunState.Phase.ENDED and not main.engine_audio.playing, "Ending must stop audio in the same frame")
	main._restart_run()
	assert(not main.engine_audio.playing and not main.collision_audio.playing, "R must clear active audio")
	await _teardown_audio_main(main)
	quit()

func _teardown_audio_main(main: Node) -> void:
	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	await process_frame
	await process_frame
