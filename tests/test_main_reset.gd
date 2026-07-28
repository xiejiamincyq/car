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
	main.free()
	quit()
