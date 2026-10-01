extends SceneTree
const MainScene = preload("res://scenes/main.tscn")
const Launcher = preload("res://tests/PlaytestLauncher.gd")
const Config = preload("res://tests/playtest_launch_config.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	var config := Config.parse(PackedStringArray(["neon_coast","pulse_gt","standard","611"]))
	Launcher.configure_main(main,config)
	var recorder = Launcher.attach_recorder(main)
	recorder.set_process(false)
	var path: String = recorder.output_path
	assert(not path.is_empty() and not main.persistence_enabled)
	assert(recorder.source_label == "automated_headless")
	recorder._process(0)
	main.run.start()
	main.run.phase = main.RunState.Phase.RUNNING
	main.run.tick(1,500,760)
	main.run.award_coin()
	main.integrity.current = 73.0
	recorder._process(0)
	main.run.mark_clear()
	recorder._process(0)
	recorder._process(0)
	Launcher.configure_main(main,config)
	recorder._process(0)
	main.run.phase = main.RunState.Phase.RUNNING
	main.run.fail_integrity()
	recorder._process(0)
	Launcher.configure_main(main,config)
	recorder._process(0)
	main.run.phase = main.RunState.Phase.RUNNING
	main.run.mark_clear()
	# Exit before the observer's next frame: the terminal result must win.
	main.queue_free()
	await process_frame
	var file := FileAccess.open(path,FileAccess.READ)
	var cleared: Dictionary = JSON.parse_string(file.get_line())
	var failed: Dictionary = JSON.parse_string(file.get_line())
	var exit_result: Dictionary = JSON.parse_string(file.get_line())
	assert(cleared.outcome == "clear" and cleared.coins == 1 and cleared.integrity == 73)
	assert(failed.outcome == "failed" and failed.failure_reason == "integrity")
	assert(exit_result.outcome == "clear" and exit_result.source == "automated_headless", "Closing on the finish frame must not downgrade the result to aborted")
	assert(file.get_line().is_empty(), "Exactly one record per attempt")
	file.close()
	DirAccess.remove_absolute(path)
	quit()
