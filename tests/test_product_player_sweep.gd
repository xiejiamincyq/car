extends SceneTree

## Natural seed reproduction of one missed gameplay-collider corner crossing.
## No fake collision rectangle, injected NPC/resource, or player teleport.
const MainScene = preload("res://scenes/main.tscn")
const Launcher = preload("res://tests/PlaytestLauncher.gd")
const Audit = preload("res://scripts/tests/ProductMainAudit.gd")
const Config = preload("res://scripts/game_config.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
const DT := 1.0 / 60.0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	Launcher.configure_main(main, {"track_id":"neon_coast", "vehicle_id":"pulse_gt", "difficulty_index":1, "run_seed":9001})
	_check(not main.persistence_enabled, "isolated reproduction never opens formal save")
	for countdown_frame in range(181):
		if main.run.phase != main.RunState.Phase.COUNTDOWN: break
		main._process(DT)
	_key(true)
	var found := false
	var lane_width := Config.ROAD_HALF_WIDTH * 2.0 / Config.ROAD_LANE_COUNT
	var player_y: float = main.TrackGeometry.player_y(720.0)
	for frame in range(225):
		var previous := {}
		var player_x_before: float = main.drive.lateral_position
		var speed_before: float = main.drive.speed
		var collisions_before: int = main.run.collisions
		var cooldown_before: float = main.impact_cooldown
		for npc in main.traffic.vehicles:
			previous[npc.get_instance_id()] = {"x":(npc.lane_position - 1.0) * lane_width, "y":npc.y, "generation":npc.motion_generation}
		main._process(DT)
		for npc in main.traffic.vehicles:
			if not previous.has(npc.get_instance_id()): continue
			var old: Dictionary = previous[npc.get_instance_id()]
			if old.generation != npc.motion_generation: continue
			var start := Vector2(old.x - player_x_before, old.y - player_y)
			var end := Vector2((npc.lane_position - 1.0) * lane_width - main.drive.lateral_position, npc.y - player_y)
			# Exactly Main's gameplay collider contract, not sprite bounds.
			var extents := Vector2(Config.COLLISION_LATERAL_DISTANCE + npc.half_width - 25.0, Config.COLLISION_LONGITUDINAL_DISTANCE + npc.half_length - 42.0)
			_check(extents == Vector2(main.traffic.collision_lateral_distance_for(npc), main.traffic.collision_distance_for(npc)), "independent formula matches real gameplay collision extents")
			if Audit._inside(start, extents) or Audit._inside(end, extents): continue
			if not Audit.swept_contact(start, end, extents): continue
			found = true
			print("PLAYER_SWEEP_REPRO ", JSON.stringify({"seed":9001, "frame":frame, "dt":DT, "seconds":main.run.elapsed_seconds, "player_speed_before":speed_before, "player_x_before":player_x_before, "player_x_after":main.drive.lateral_position, "player_y":player_y, "npc_actual_speed":npc.actual_world_speed, "npc_lateral_velocity":npc.lateral_velocity, "npc_kind":npc.kind, "start":[start.x,start.y], "end":[end.x,end.y], "gameplay_extents":[extents.x,extents.y], "impact_cooldown_before":cooldown_before, "collisions_before":collisions_before, "collisions_after":main.run.collisions, "npc_contact":npc.collided_with_player}))
			_check(cooldown_before <= 0.0, "missed corner entry is not suppressed by impact cooldown")
			_check(main.run.collisions > collisions_before and npc.collided_with_player, "real Main must register the closing swept corner contact despite clear endpoints")
	_check(found, "natural seed9001 includes the targeted swept corner crossing")
	_key(false)
	var refs: Array[WeakRef] = AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, refs), "reproduction audio retires cleanly")
	for failure in failures: push_error("PLAYER_SWEEP " + failure)
	print("PRODUCT_PLAYER_SWEEP failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_player_sweep.gd")
	quit(0 if failures.is_empty() else 1)

func _key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
