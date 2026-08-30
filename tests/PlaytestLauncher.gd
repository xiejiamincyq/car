extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const PlaytestLaunchConfig = preload("res://tests/playtest_launch_config.gd")

func _init() -> void:
	call_deferred("_launch")

func _launch() -> void:
	var config := PlaytestLaunchConfig.parse(OS.get_cmdline_user_args())
	if not bool(config.valid):
		push_error("%s\nUsage: -- <track_id> <vehicle_id> <easy|standard|hard|0..2> <seed>" % config.error)
		quit(2)
		return

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	# The launcher changes only this process's in-memory selections. Real player
	# progress and settings remain untouched during a reproducible playtest.
	main.persistence_enabled = false
	main.save_data["tour"]["selected_track_id"] = config.track_id
	main.save_data["tour"]["selected_vehicle_id"] = config.vehicle_id
	main.difficulty_index = config.difficulty_index
	main._apply_selected_vehicle()
	main._apply_selected_track()
	main._reset_run(config.run_seed)
	main.run.begin_countdown()
	main._update_hud()
	main.queue_redraw()

	print("PLAYTEST track=%s vehicle=%s difficulty=%d seed=%d persistence=off" % [
		config.track_id,
		config.vehicle_id,
		config.difficulty_index,
		config.run_seed,
	])
