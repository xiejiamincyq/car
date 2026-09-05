extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	main.run.start()
	main.drive.speed = main.drive.max_speed
	var npc = main.traffic.acquire_vehicle(0, 1, main.TrackGeometry.player_y(main.get_viewport_rect().size.y))
	main.traffic.vehicles.append(npc)
	var npc_y: float = npc.y
	main._check_collisions()
	assert(is_equal_approx(npc.y, npc_y), "A player collision must not teleport an NPC into another car")
	assert(is_equal_approx(main.integrity.current, 78.0))
	assert(main.run.collisions == 1)
	main._check_collisions()
	assert(main.run.collisions == 1, "Invulnerability must prevent repeat damage")
	main.integrity.current = 25.0
	main._apply_cone_hit(Vector2.ZERO, Vector2.ONE)
	assert(main.run.failure_reason == &"integrity" and main.run.phase == main.RunState.Phase.GAME_OVER)
	main._update_hud()
	assert(main.result_summary.text.contains("完整度低于20%"))
	main._reset_run(611)
	assert(main.integrity.current == 100.0 and main.run.collisions == 0)
	main.run.start()
	main.integrity.current = 30.0
	main.drive.speed = main.drive.max_speed
	main._process(0.0)
	assert(is_equal_approx(main.drive.speed, main.drive.max_speed * 0.78))
	assert(main.integrity_label.text.contains("030%"))
	main.free()
	quit()
