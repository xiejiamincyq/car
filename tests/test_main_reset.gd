extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	assert(InputMap.has_action("overdrive_tap"), "The main scene must register a dedicated W-only overdrive tap action")
	var overdrive_events := InputMap.action_get_events("overdrive_tap")
	assert(overdrive_events.size() == 1 and overdrive_events[0] is InputEventKey and overdrive_events[0].keycode == KEY_W, "The Up arrow must continue accelerating without counting toward the W-only double tap")
	main.drive.speed = 0.0
	main.road_scroll = 50.0
	main.collision.invulnerability_remaining = 0.5
	main.screen_shake = Vector2(5.0, 5.0)
	main.run.start()
	main.run.tick(4.0, 760.0, 760.0)
	main.fuel_pickups.append(preload("res://scripts/fuel_pickup.gd").new(1, 300.0))
	main.traffic.tick(1.0, 500.0, 1)
	main.audio_director.collision_audio.play()
	main.overdrive.observe_accelerate_press(100.0, 100.0)
	main.overdrive.tick(0.1, 100.0)
	main.overdrive.observe_accelerate_press(100.0, 100.0)
	assert(main.overdrive.is_active(), "The reset regression must begin with active overdrive")
	var fuel_before_overdrive: float = main.run.fuel
	var speed_before_overdrive: float = main.drive.speed
	Input.action_press("accelerate")
	main._process(main.GameConfig.OVERDRIVE_RAMP_IN_SECONDS)
	Input.action_release("accelerate")
	assert(main.run.fuel < fuel_before_overdrive, "The main loop must apply gradual overdrive fuel consumption to the active run")
	assert(main.drive.speed > speed_before_overdrive, "The main loop must apply overdrive acceleration to the selected vehicle")
	assert(main.drive.speed <= main.drive.max_speed + main.GameConfig.OVERDRIVE_SPEED_BONUS, "The main loop must respect the temporary 100 km/h ceiling")
	var active_remaining_before_pause: float = main.overdrive.active_remaining
	main.run.toggle_pause()
	main._process(0.5)
	assert(is_equal_approx(main.overdrive.active_remaining, active_remaining_before_pause), "Pausing must freeze the active overdrive timer")
	main.run.phase = main.RunState.Phase.RUNNING
	main._reset_run()
	assert(is_equal_approx(main.drive.speed, 280.0), "R reset must restore driving speed")
	assert(is_zero_approx(main.road_scroll), "R reset must clear road scroll")
	assert(main.traffic.vehicles.is_empty(), "R reset must remove traffic")
	assert(is_zero_approx(main.collision.invulnerability_remaining), "R reset must clear invulnerability")
	assert(main.screen_shake == Vector2.ZERO, "R reset must clear screen shake")
	assert(main.audio_director.collision_audio.stream != null, "R reset must retain collision audio readiness")
	assert(not main.audio_director.collision_audio.playing, "R reset must stop active collision audio")
	assert(main.run.phase == main.RunState.Phase.READY, "Reset must return the run to its start state")
	assert(main.run.score == 0 and is_zero_approx(main.run.distance), "Reset must clear score and distance")
	assert(is_equal_approx(main.run.fuel, 100.0), "Reset must restore the full fuel tank")
	assert(main.fuel_pickups.is_empty(), "Reset must remove old fuel pickups")
	assert(main.overdrive.is_ready(), "Reset must clear overdrive state and cooldown")
	await _teardown_audio_main(main)
	quit()

func _teardown_audio_main(main: Node) -> void:
	main.audio_director.stop_run_audio()
	for player in [main.audio_director.collision_audio, main.audio_director.engine_audio, main.audio_director.acceleration_audio, main.audio_director.pickup_audio, main.audio_director.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	await process_frame
	await process_frame
