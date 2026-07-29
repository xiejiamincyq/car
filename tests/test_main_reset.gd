extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.drive.speed = 0.0
	main.road_scroll = 50.0
	main.collision.invulnerability_remaining = 0.5
	main.screen_shake = Vector2(5.0, 5.0)
	main.run.start()
	main.run.tick(4.0, 760.0, 760.0)
	main.fuel_pickups.append(preload("res://scripts/fuel_pickup.gd").new(1, 300.0))
	main.traffic.tick(1.0, 500.0, 1)
	main.collision_audio.play()
	main._reset_run()
	assert(is_equal_approx(main.drive.speed, 280.0), "R reset must restore driving speed")
	assert(is_zero_approx(main.road_scroll), "R reset must clear road scroll")
	assert(main.traffic.vehicles.is_empty(), "R reset must remove traffic")
	assert(is_zero_approx(main.collision.invulnerability_remaining), "R reset must clear invulnerability")
	assert(main.screen_shake == Vector2.ZERO, "R reset must clear screen shake")
	assert(main.collision_audio.stream != null, "R reset must retain collision audio readiness")
	assert(not main.collision_audio.playing, "R reset must stop active collision audio")
	assert(main.run.phase == main.RunState.Phase.READY, "Reset must return the run to its start state")
	assert(main.run.score == 0 and is_zero_approx(main.run.distance), "Reset must clear score and distance")
	assert(is_equal_approx(main.run.fuel, 100.0), "Reset must restore the full fuel tank")
	assert(main.fuel_pickups.is_empty(), "Reset must remove old fuel pickups")
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
