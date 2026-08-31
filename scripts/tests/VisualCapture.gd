extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RunState = preload("res://scripts/run_state.gd")
const TrackRuntimeProfile = preload("res://scripts/track_runtime_profile.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	_capture()

func _capture() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 5:
		push_error("Usage: -- <track_id> <distance_ratio> <output.png> <width> <height> [high_contrast]")
		quit(2)
		return
	var track_id := StringName(arguments[0])
	var distance_ratio := clampf(float(arguments[1]), 0.0, 1.0)
	var output_path := arguments[2]
	var capture_size := Vector2i(maxi(640, int(arguments[3])), maxi(360, int(arguments[4])))
	var high_contrast := arguments.size() >= 6 and arguments[5] == "true"

	DisplayServer.window_set_size(capture_size)
	await process_frame
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	main.current_track = TrackRuntimeProfile.resolve(track_id)
	main.current_environment_left = TrackRuntimeProfile.textures_for(main.current_track, "left", main.COAST_LEFT_TEXTURE)
	main.current_environment_right = TrackRuntimeProfile.textures_for(main.current_track, "right", main.COAST_RIGHT_TEXTURE)
	TrackRuntimeProfile.apply(main.current_track, main.drive, main.run, main.traffic)
	main.run.phase = RunState.Phase.RUNNING
	main.run.distance = main.run.progression.finish_distance * distance_ratio
	main.drive.speed = 200.0
	main.high_contrast_enabled = high_contrast
	if arguments.size() >= 7 and arguments[6] == "lane_change_preview":
		_stage_lane_change_preview(main)
	_hide_overlays(main)
	main.race_hud.visible = true
	main._update_hud()
	main.queue_redraw()
	main.roadside_renderer.queue_redraw()

	await process_frame
	await RenderingServer.frame_post_draw
	var image := main.get_viewport().get_texture().get_image()
	if image.get_size() != capture_size:
		push_error("Capture viewport is %s instead of requested %s" % [image.get_size(), capture_size])
		quit(4)
		return
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Unable to save capture to %s: %s" % [output_path, error_string(error)])
		quit(3)
		return
	print("CAPTURED %s %0.2f %dx%d -> %s" % [track_id, distance_ratio, capture_size.x, capture_size.y, output_path])
	main.queue_free()
	await process_frame
	quit()

func _stage_lane_change_preview(main: Node) -> void:
	main.traffic.reset()
	var change_right = main.traffic.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, 370.0, 200.0)
	change_right.target_lane = 1
	change_right.warning_started = true
	change_right.warning_remaining = 0.5
	var change_left = main.traffic.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 2, 480.0, 200.0)
	change_left.target_lane = 1
	change_left.warning_started = true
	change_left.warning_remaining = 0.5
	main.traffic.vehicles.assign([change_right, change_left])

func _hide_overlays(main: Node) -> void:
	for control_name in [
		"menu_backdrop",
		"overlay_shade",
		"title_screen",
		"tour_map_screen",
		"vehicle_select_screen",
		"settings_screen",
		"controls_screen",
		"countdown_screen",
		"pause_screen",
		"result_screen",
		"confirmation_screen",
	]:
		var control = main.get(control_name)
		if control != null:
			control.visible = false
	main.overlay_label.visible = false
