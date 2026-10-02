extends SceneTree
## Synthetic visual fixture, not a natural gameplay or input recording.
## Runs Main's actual _draw(), then samples real rendered process frames.

const MainScene = preload("res://scenes/main.tscn")
const Catalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const VehicleAnimation = preload("res://scripts/vehicle_visual_animation.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
const PROBE_COLOR := Color(1.0, 0.0, 1.0, 1.0)

class CaptureMain extends "res://scripts/main.gd":
	func _draw() -> void:
		super._draw()
		# No draw_set_transform here: this catches a leaked body/shake transform.
		var viewport := get_viewport_rect().size
		draw_rect(Rect2(viewport.x * 0.5 - 6.0, viewport.y - 16.0, 12.0, 12.0), Color(1, 0, 1))

var output_dir := "res://tmp/product-tail-capture-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var main
var states: Array[Dictionary] = []
var failures := 0

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Actual tail capture needs a rendering display; do not use --headless")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir)) != OK:
		quit(3)
		return
	main = MainScene.instantiate()
	main.set_script(CaptureMain)
	main.persistence_enabled = false
	root.add_child(main) # Deliberately NOT current_scene: _ready does not load user://save.cfg.
	main.set_process(false)
	if current_scene == main or main.persistence_enabled:
		push_error("Capture must never enable persistence")
		quit(4)
		return
	main.run.phase = main.RunState.Phase.RUNNING
	main.run.distance = 1800.0
	main.drive.speed = 280.0
	main.traffic.vehicles.clear()
	main.fuel_pickups.clear()
	main.coin_director.coins.clear()
	main.repair_supplies.pickups.clear()
	main.audio_director.shutdown()
	_hide_overlays()
	print("TAIL_CAPTURE synthetic=true natural_play=false persistence=false actual_main_draw=true output=", ProjectSettings.globalize_path(output_dir))
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(size)
		await process_frame
		await process_frame
		for mode in ["normal", "boost_impact", "boost_impact_reduced"]:
			var sheet := Image.create(3 * 280, 6 * 240, false, Image.FORMAT_RGBA8)
			var vehicle_index := 0
			for vehicle in Catalog.all():
				_select_vehicle(vehicle)
				for pose in range(3):
					var steer: float = [0.0, -1.0, 1.0][pose]
					_stage(mode, steer, 1.7, 0.23 if mode != "normal" else 0.0)
					var label := "%dx%d_%s_%s_%s" % [size.x, size.y, vehicle.id, mode, ["zero", "left15", "right15"][pose]]
					var frame: Image = await _sample(size, label, vehicle_index == 0 and pose == 0)
					var center := Vector2i(size.x / 2, int(main.TrackGeometry.player_y(size.y)))
					var crop := frame.get_region(Rect2i(center - Vector2i(140, 130), Vector2i(280, 240)))
					sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(pose * 280, vehicle_index * 240))
				vehicle_index += 1
			_check(sheet.save_png(output_dir + "/sheet_%dx%d_%s.png" % [size.x, size.y, mode]) == OK, "contact sheet saved")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	await process_frame
	_select_vehicle(Catalog.all()[0])
	var motion_sheet := Image.create(6 * 280, 4 * 240, false, Image.FORMAT_RGBA8)
	for index in range(24):
		var progress := float(index) / 23.0
		var steer := sin(progress * TAU)
		var remaining := maxf(0.0, VehicleAnimation.COLLISION_DURATION - progress * 0.8)
		_stage("boost_impact", steer, 2.0 + progress * 0.8, remaining)
		main.road_scroll = progress * 92.0
		var frame: Image = await _sample(Vector2i(1280, 720), "motion_%02d" % index)
		var center := Vector2i(640, int(main.TrackGeometry.player_y(720)))
		var crop := frame.get_region(Rect2i(center - Vector2i(140, 130), Vector2i(280, 240)))
		motion_sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((index % 6) * 280, (index / 6) * 240))
	_check(motion_sheet.save_png(output_dir + "/sheet_motion.png") == OK, "motion contact sheet saved")
	var manifest := FileAccess.open(output_dir + "/frames.json", FileAccess.WRITE)
	_check(manifest != null, "frame manifest opened")
	if manifest != null:
		manifest.store_string(JSON.stringify({"synthetic": true, "natural_play": false, "frames": states}, "\t"))
		manifest.close()
	var playbacks := AudioTeardown.capture(main)
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, playbacks), "audio teardown complete")
	print("TAIL_CAPTURE_COMPLETE frames=%d failures=%d output=%s" % [states.size(), failures, ProjectSettings.globalize_path(output_dir)])
	quit(0 if failures == 0 else 1)

func _select_vehicle(vehicle: Dictionary) -> void:
	main.current_vehicle = vehicle
	main.current_player_texture = main.PlayerVehicleProfile.texture_for(vehicle)

func _stage(mode: String, steer: float, time: float, collision_remaining: float) -> void:
	main.steering_visual_strength = steer
	main.visual_animation_time = time
	main.collision_visual_remaining = collision_remaining
	main.collision_visual_direction = -1.0 if steer < 0.0 else 1.0
	main.integrity.current = 100.0 if mode == "normal" else 25.0
	main.reduced_flashing_enabled = mode.ends_with("reduced")
	main.acceleration_visual_strength = 1.0
	main.brake_visual_strength = 0.0
	main.screen_shake = Vector2(7, -4) if collision_remaining > 0.0 else Vector2.ZERO
	main.overdrive.reset()
	if mode != "normal":
		main.overdrive.observe_accelerate_press(100.0, 100.0)
		main.overdrive.observe_accelerate_press(100.0, 100.0)
		main.overdrive.tick(main.GameConfig.OVERDRIVE_RAMP_IN_SECONDS, 100.0)
	main._update_hud()
	_hide_overlays()

func _sample(expected_size: Vector2i, label: String, save_full: bool = true) -> Image:
	main.queue_redraw()
	main.roadside_renderer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame.get_size() == expected_size, "actual viewport matches " + label)
	var probe := frame.get_pixel(expected_size.x / 2, expected_size.y - 10)
	var restored := absf(probe.r - PROBE_COLOR.r) < 0.02 and absf(probe.g - PROBE_COLOR.g) < 0.02 and absf(probe.b - PROBE_COLOR.b) < 0.02
	_check(restored, "post-Main identity-transform probe " + label)
	if save_full:
		_check(frame.save_png(output_dir + "/" + label + ".png") == OK, "frame saved " + label)
	var body_rotation: float = VehicleAnimation.steering_rotation(main.steering_visual_strength) + VehicleAnimation.collision_rotation(main.collision_visual_remaining, main.collision_visual_direction) + VehicleAnimation.damage_wobble(main.visual_animation_time, main.integrity.condition(), main.reduced_flashing_enabled)
	var state := {"sample": label, "file": label + ".png" if save_full else "contact-sheet-only", "viewport": [frame.get_width(), frame.get_height()], "vehicle": String(main.current_vehicle.id), "steer": main.steering_visual_strength, "steer_degrees": rad_to_deg(VehicleAnimation.steering_rotation(main.steering_visual_strength)), "body_degrees": rad_to_deg(body_rotation), "time": main.visual_animation_time, "collision_remaining": main.collision_visual_remaining, "integrity": main.integrity.current, "reduced": main.reduced_flashing_enabled, "overdrive": main.overdrive.intensity(), "transform_probe_identity": restored, "engine_process_frame": Engine.get_process_frames()}
	states.append(state)
	print("TAIL_FRAME ", JSON.stringify(state))
	return frame

func _hide_overlays() -> void:
	for name in ["menu_backdrop", "overlay_shade", "title_screen", "tour_map_screen", "vehicle_select_screen", "settings_screen", "controls_screen", "countdown_screen", "pause_screen", "result_screen", "confirmation_screen", "overlay_label"]:
		var control = main.get(name)
		if control != null:
			control.hide()
	main.race_hud.show()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("TAIL_CAPTURE " + message)
