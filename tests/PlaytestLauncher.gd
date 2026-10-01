extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const PlaytestLaunchConfig = preload("res://tests/playtest_launch_config.gd")
const SessionRecorder = preload("res://tests/playtest_session_recorder.gd")

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
	configure_main(main, config)
	attach_recorder(main)

	print("PLAYTEST track=%s vehicle=%s difficulty=%d seed=%d persistence=off" % [
		config.track_id,
		config.vehicle_id,
		config.difficulty_index,
		config.run_seed,
	])

static func attach_recorder(main):
	var recorder := SessionRecorder.new()
	recorder.source_main = main
	recorder.source_label = "automated_headless" if DisplayServer.get_name() == "headless" else "interactive_unverified"
	var folder := "user://playtests"
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error == OK:
		var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
		recorder.output_path = "%s/session-%s-%d.jsonl" % [folder,stamp,Time.get_ticks_usec()]
	else:
		push_warning("Cannot create playtest log folder; recording disabled")
	main.add_child(recorder)
	if not recorder.output_path.is_empty():
		print("PLAYTEST_LOG ",ProjectSettings.globalize_path(recorder.output_path))
	return recorder


static func configure_main(main, config: Dictionary) -> void:
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
	main.audio_director.begin_music_countdown(StringName(main.current_track.get("music_id", &"")))
	main._update_hud()
	main.queue_redraw()
