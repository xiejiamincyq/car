extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const MainScript = preload("res://scripts/main.gd")
const Config = preload("res://scripts/game_config.gd")
const Catalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const PlayerProfile = preload("res://scripts/player_vehicle_profile.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
const FUEL_INTERVALS := [4.5, 7.0, 10.0]
const REPAIR_INTERVALS := [8.0, 12.0, 18.0]
var failures: Array[String] = []
class ConstructionStopMain extends MainScript:
	func _check_construction_collisions() -> void:
		# Controlled collision-stage slowdown, not a natural collision claim.
		drive.speed = 0.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	_check(not main.persistence_enabled and current_scene == null, "isolated integration does not open formal persistence/current_scene")
	_normal_render_length()
	for difficulty in range(3):
		_difficulty_and_idempotence(main, difficulty)
	_stationary_and_pause(main)
	_changed_difficulty_and_restart(main)
	_capacity_spacing_and_no_debt(main)
	_rng_and_existing_spawn_history(main)
	_variable_step_birth_spacing(main)
	_rewards_and_world_motion(main)
	await _road_snapshot_cases()
	var refs: Array[WeakRef] = AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, refs), "all integration audio playbacks retire")
	for failure in failures:
		push_error("SUPPLY_INTEGRATION " + failure)
	print("PRODUCT_SUPPLY_INTEGRATION failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_supply_integration.gd")
	quit(0 if failures.is_empty() else 1)

func _fresh(main, difficulty: int = 1) -> void:
	main.difficulty_index = difficulty
	main._reset_run(9001)
	main.run.start()
	main.traffic._spawn_cooldown = 1000.0
	main.traffic.lane_events.enabled = false
	main.drive.speed = 200.0

func _difficulty_and_idempotence(main, difficulty: int) -> void:
	_fresh(main, difficulty)
	var fuel = main.fuel_spawn_director
	var repair = main.repair_supplies.spawner
	print("SUPPLY_DIFFICULTY ", JSON.stringify({"difficulty":difficulty,"fuel":fuel.spawn_interval,"repair":repair.spawn_interval}))
	_check(fuel.spawn_interval == FUEL_INTERVALS[difficulty], "Main fuel interval for difficulty %d is %.0f" % [difficulty, FUEL_INTERVALS[difficulty]])
	_check(repair.spawn_interval == REPAIR_INTERVALS[difficulty], "Main repair interval for difficulty %d is %.0f" % [difficulty, REPAIR_INTERVALS[difficulty]])
	_check(fuel.active_limit == 2 and repair.active_limit == 2, "Main connects cap2 for both supply classes")
	_check(fuel.minimum_road_advance == 136.0 and repair.minimum_road_advance == 136.0, "Main connects render-derived136 spacing for both classes")
	main._update_fuel_pickups(1.0)
	main._update_repair_pickups(1.0)
	var fuel_remaining: float = fuel.spawn_remaining
	var repair_remaining: float = repair.spawn_remaining
	for repeat in range(4):
		main._apply_difficulty_profile()
	_check(fuel.spawn_remaining == fuel_remaining and repair.spawn_remaining == repair_remaining, "same-profile Main application preserves both partial timers")

func _stationary_and_pause(main) -> void:
	_fresh(main)
	main.drive.speed = 0.0
	var fuel_timer: float = main.fuel_spawn_director.spawn_remaining
	var repair_timer: float = main.repair_supplies.spawner.spawn_remaining
	main._process(1.0)
	print("SUPPLY_PARKED ", JSON.stringify({"fuel_before":fuel_timer,"fuel_after":main.fuel_spawn_director.spawn_remaining,"repair_before":repair_timer,"repair_after":main.repair_supplies.spawner.spawn_remaining}))
	_check(main.fuel_spawn_director.spawn_remaining == fuel_timer and main.repair_supplies.spawner.spawn_remaining == repair_timer, "actual parked Main frame freezes both supply timers")
	_check(main.fuel_pickups.is_empty() and main.repair_supplies.pickups.is_empty(), "parking cannot create supplies")
	main.fuel_pickups.append(main.FuelPickup.new(0, 180.0))
	main.repair_supplies.pickups.append(main.FuelPickup.new(2, 280.0))
	main.drive.speed = 200.0
	main._pause_run()
	var fuel_y: float = main.fuel_pickups[0].y
	var repair_y: float = main.repair_supplies.pickups[0].y
	fuel_timer = main.fuel_spawn_director.spawn_remaining
	repair_timer = main.repair_supplies.spawner.spawn_remaining
	main._process(1.0)
	_check(main.fuel_pickups[0].y == fuel_y and main.repair_supplies.pickups[0].y == repair_y, "paused Main frame freezes world movement")
	_check(main.fuel_spawn_director.spawn_remaining == fuel_timer and main.repair_supplies.spawner.spawn_remaining == repair_timer, "paused Main frame freezes both partial timers")
	main._reset_run(9001)
	main.run.begin_countdown()
	fuel_timer = main.fuel_spawn_director.spawn_remaining
	repair_timer = main.repair_supplies.spawner.spawn_remaining
	main._process(0.25)
	_check(main.fuel_spawn_director.spawn_remaining == fuel_timer and main.repair_supplies.spawner.spawn_remaining == repair_timer, "countdown freezes both supply timers")

func _changed_difficulty_and_restart(main) -> void:
	_fresh(main, 0)
	main._update_fuel_pickups(1.0)
	main._update_repair_pickups(1.0)
	var fuel = main.FuelPickup.new(0, 180.0)
	var repair = main.FuelPickup.new(2, 280.0)
	main.fuel_pickups.append(fuel)
	main.repair_supplies.pickups.append(repair)
	main.difficulty_index = 2
	main._apply_difficulty_profile()
	_check(main.fuel_pickups.has(fuel) and main.repair_supplies.pickups.has(repair), "difficulty change preserves existing pickup identities")
	_check(main.fuel_spawn_director.spawn_remaining == 10.0 and main.repair_supplies.spawner.spawn_remaining == 18.0, "difficulty change starts fresh future hard intervals")
	main._reset_run(9001)
	_check(main.fuel_pickups.is_empty() and main.repair_supplies.pickups.is_empty(), "restart clears both pickup sets")
	_check(main.fuel_spawn_director.spawn_remaining == 10.0 and main.repair_supplies.spawner.spawn_remaining == 18.0, "restart applies the selected difficulty schedule")

func _capacity_spacing_and_no_debt(main) -> void:
	for kind in ["fuel", "repair"]:
		_fresh(main)
		main.drive.speed = 1.0
		var spawner = _spawner(main, kind)
		_pickups(main, kind).append(main.FuelPickup.new(0, 300.0))
		_pickups(main, kind).append(main.FuelPickup.new(2, 400.0))
		spawner.spawn_remaining = 0.0
		_update_supply(main, kind, 0.1)
		_check(_pickups(main, kind).size() == 2 and spawner.pending, "Main passes actual %s active count; cap2 defers one pending event" % kind)
		var pending_timer: float = spawner.spawn_remaining
		var pending_progress: float = spawner.road_advance_since_spawn
		var pending_attempts: int = spawner.blocked_attempts
		main.drive.speed = 0.0
		_update_supply(main, kind, 10.0)
		_check(spawner.pending and spawner.spawn_remaining == pending_timer and spawner.road_advance_since_spawn == pending_progress and spawner.blocked_attempts == pending_attempts, "%s parking freezes an already-pending retry without a retry storm" % kind)
		main.drive.speed = 1.0
		_pickups(main, kind).pop_back()
		_update_supply(main, kind, 0.5)
		_check(_pickups(main, kind).size() == 2 and not spawner.pending and spawner.spawned == 1, "%s pending admission releases exactly one pickup when capacity returns" % kind)
		_check(spawner.spawn_remaining == spawner.spawn_interval, "%s successful birth starts one full interval" % kind)
		for retry in range(50):
			_update_supply(main, kind, 0.5)
		_check(_pickups(main, kind).size() == 2 and spawner.pending and spawner.opportunities == 2, "%s repeated cap retries remain one pending opportunity, not interval debt" % kind)
		pending_timer = spawner.spawn_remaining
		pending_progress = spawner.road_advance_since_spawn
		pending_attempts = spawner.blocked_attempts
		for repeat in range(4):
			main._apply_difficulty_profile()
		_check(spawner.pending and spawner.spawn_remaining == pending_timer and spawner.road_advance_since_spawn == pending_progress and spawner.blocked_attempts == pending_attempts, "%s identical Main configuration preserves the pending opportunity and road baseline" % kind)
		_pickups(main, kind).clear()
		_update_supply(main, kind, 0.5)
		_check(_pickups(main, kind).is_empty(), "%s pending release still requires136 roadpx since the last real birth" % kind)
		var before: int = spawner.spawned
		_update_supply(main, kind, 120.0)
		_check(spawner.spawned == before + 1 and _pickups(main, kind).size() == 1, "%s a long moving step releases at most one pending event" % kind)
		_check(not spawner.pending and spawner.spawn_remaining == spawner.spawn_interval, "%s no accumulated debt remains after the long-step admission" % kind)
		var progress: float = spawner.road_advance_since_spawn
		var remaining: float = spawner.spawn_remaining
		main.drive.speed = 0.0
		_update_supply(main, kind, 8.0)
		_check(spawner.road_advance_since_spawn == progress and spawner.spawn_remaining == remaining, "%s no-motion frame freezes future road progress and timer" % kind)
		main.drive.speed = 200.0
		_update_supply(main, kind, 0.0)
		_check(spawner.road_advance_since_spawn == progress and spawner.spawn_remaining == remaining, "%s zero-time frame cannot accrue road progress" % kind)
		print("SUPPLY_MAIN_GATES ", JSON.stringify({"kind":kind,"spawned":spawner.spawned,"opportunities":spawner.opportunities,"active":_pickups(main, kind).size(),"road_progress":spawner.road_advance_since_spawn}))

func _rng_and_existing_spawn_history(main) -> void:
	for kind in ["fuel", "repair"]:
		_fresh(main, 0)
		var first := _capture_sequence(main, kind, 4)
		var spawner = _spawner(main, kind)
		var random_state: int = spawner._random.state
		main.difficulty_index = 2
		main._apply_difficulty_profile()
		_check(spawner._random.state == random_state, "%s configuration change never reseeds or draws RNG" % kind)
		_check(spawner.has_spawned and spawner.road_advance_since_spawn == 0.0, "%s changing configuration preserves non-first-birth spacing history" % kind)
		main.drive.speed = 1.0
		_update_supply(main, kind, spawner.spawn_interval)
		_check(spawner.pending and _pickups(main, kind).is_empty(), "%s difficulty switching cannot bypass non-first136 roadpx spacing" % kind)
		_fresh(main, 0)
		var replay := _capture_sequence(main, kind, 4)
		_check(first == replay and first.size() == 4, "%s same-seed Main restart reproduces pickup lanes" % kind)
		print("SUPPLY_MAIN_REPLAY ", JSON.stringify({"kind":kind,"first":first,"replay":replay}))

func _variable_step_birth_spacing(main) -> void:
	for kind in ["fuel", "repair"]:
		_fresh(main)
		var interval: float = _spawner(main, kind).spawn_interval
		main.drive.speed = 1.0 / (Config.ROAD_SCROLL_MULTIPLIER * interval)
		_update_supply(main, kind, interval)
		_check(_pickups(main, kind).size() == 1, "%s first moving interval emits one pickup" % kind)
		main.drive.speed = 136.0 / (Config.ROAD_SCROLL_MULTIPLIER * interval)
		_update_supply(main, kind, interval)
		_check(_pickups(main, kind).size() == 2, "%s second full interval with136 roadpx is admitted" % kind)
		if _pickups(main, kind).size() == 2:
			var gap: float = absf(_pickups(main, kind)[0].y - _pickups(main, kind)[1].y)
			print("SUPPLY_VARIABLE_STEP_SPACING ", JSON.stringify({"kind":kind,"first_advance":1.0,"second_advance":136.0,"actual_gap":gap,"pickup_y":[_pickups(main, kind)[0].y,_pickups(main, kind)[1].y]}))
			_check(gap >= 136.0 - 0.0001, "%s varying successful-birth frame advances preserve actual136px pickup spacing" % kind)

func _capture_sequence(main, kind: String, count: int) -> Array[int]:
	var lanes: Array[int] = []
	for step in range(1000):
		_update_supply(main, kind, 0.1)
		if not _pickups(main, kind).is_empty():
			lanes.append(_pickups(main, kind)[0].lane)
			_pickups(main, kind).clear()
		if lanes.size() == count:
			break
	return lanes

func _pickups(main, kind: String) -> Array:
	return main.fuel_pickups if kind == "fuel" else main.repair_supplies.pickups

func _spawner(main, kind: String):
	return main.fuel_spawn_director if kind == "fuel" else main.repair_supplies.spawner

func _update_supply(main, kind: String, delta: float) -> void:
	main.call("_update_fuel_pickups" if kind == "fuel" else "_update_repair_pickups", delta)

func _rewards_and_world_motion(main) -> void:
	_fresh(main)
	var player_y: float = main.TrackGeometry.player_y(720.0)
	main.run.fuel = 40.0
	main.integrity.current = 40.0
	main.fuel_pickups.append(main.FuelPickup.new(1, player_y))
	main.repair_supplies.pickups.append(main.FuelPickup.new(1, player_y))
	main._update_fuel_pickups(0.0)
	main._update_repair_pickups(0.0)
	_check(main.run.fuel == 64.0 and main.integrity.current == 60.0, "collected rewards remain fuel24 and repair20")
	_check(main.fuel_pickups.is_empty() and main.repair_supplies.pickups.is_empty(), "collected rewards are one-shot")
	_check(main.run.coins == 0 and main.run.collisions == 0, "supplies do not award coins or collisions")
	main.run.fuel = 95.0
	main.integrity.current = 95.0
	main.fuel_pickups.append(main.FuelPickup.new(1, player_y))
	main.repair_supplies.pickups.append(main.FuelPickup.new(1, player_y))
	main._update_fuel_pickups(0.0)
	main._update_repair_pickups(0.0)
	_check(main.run.fuel == 100.0 and main.integrity.current == 100.0, "both rewards cap at100")
	main.run.fuel = 40.0
	main.integrity.current = 19.0
	main.run.fail_integrity()
	main.fuel_pickups.append(main.FuelPickup.new(1, player_y))
	main.repair_supplies.pickups.append(main.FuelPickup.new(1, player_y))
	main._update_fuel_pickups(0.0)
	main._update_repair_pickups(0.0)
	_check(main.run.fuel == 40.0 and main.integrity.current == 19.0 and main.run.phase == main.RunState.Phase.GAME_OVER, "late rewards cannot revive a failed run or failed car")
	_fresh(main)
	var fuel = main.FuelPickup.new(0, 180.0)
	var repair = main.FuelPickup.new(2, 280.0)
	main.fuel_pickups.append(fuel)
	main.repair_supplies.pickups.append(repair)
	main.drive.speed = 200.0
	main._update_fuel_pickups(0.1)
	main._update_repair_pickups(0.1)
	var expected := 200.0 * Config.ROAD_SCROLL_MULTIPLIER * 0.1
	_check(absf(fuel.y - 180.0 - expected) < 0.0001 and absf(repair.y - 280.0 - expected) < 0.0001, "both supplies stay world0 and use non-modulo road advance")

func _normal_render_length() -> void:
	var longest := 0.0
	var count := 0
	for profile in Catalog.all():
		var texture := PlayerProfile.texture_for(profile)
		var size := PlayerProfile.visual_size(profile, texture.get_size())
		longest = maxf(longest, size.y)
		count += 1
	print("SUPPLY_RENDER_LENGTH ", JSON.stringify({"vehicles":count,"longest":longest,"contract_minimum":136.0}))
	_check(count == 6 and absf(longest - 136.0) < 0.001, "six-car longest normal rendered length remains136roadpx; asset changes require explicit spacing review")

func _road_snapshot_cases() -> void:
	for delta in [0.1, 0.5]:
		var main = MainScene.instantiate()
		main.set_script(ConstructionStopMain)
		main.persistence_enabled = false
		root.add_child(main)
		main.set_process(false)
		_fresh(main)
		main.road_scroll = 90.0
		var fuel = main.FuelPickup.new(0, 0.0)
		var repair = main.FuelPickup.new(2, 200.0)
		main.fuel_pickups.append(fuel)
		main.repair_supplies.pickups.append(repair)
		# Independently compute drive.step's input contract before the collision
		# hook changes speed; never derive expected motion from new supply fields.
		var predicted_speed: float = maxf(0.0, main.drive.speed - main.drive.rolling_resistance * delta)
		var expected_advance: float = predicted_speed * Config.ROAD_SCROLL_MULTIPLIER * delta
		var fuel_timer: float = main.fuel_spawn_director.spawn_remaining
		var repair_timer: float = main.repair_supplies.spawner.spawn_remaining
		main._process(delta)
		print("SUPPLY_ROAD_SNAPSHOT ", JSON.stringify({"controlled_collision_stage_stop":true,"dt":delta,"expected_non_modulo_advance":expected_advance,"scroll_before":90.0,"scroll_after":main.road_scroll,"fuel_moved":fuel.y,"repair_moved":repair.y - 200.0,"final_speed":main.drive.speed}))
		_check(main.drive.speed == 0.0, "controlled collision-stage slowdown ran")
		_check(absf(fuel.y - expected_advance) < 0.0001 and absf(repair.y - 200.0 - expected_advance) < 0.0001, "collision-stage slowdown preserves already-advanced road motion dt=%s" % delta)
		_check(absf(main.road_scroll - fposmod(90.0 + expected_advance, main.ROAD_MARK_REPEAT_DISTANCE)) < 0.0001, "real road scroll wraps independently of supply spacing")
		_check(absf(main.fuel_spawn_director.spawn_remaining - fuel_timer + delta) < 0.0001 and absf(main.repair_supplies.spawner.spawn_remaining - repair_timer + delta) < 0.0001, "positive frame road travel advances supply timers despite post-construction speed0")
		var refs: Array[WeakRef] = AudioTeardown.capture(main)
		main.audio_director.shutdown()
		main.free()
		await process_frame
		_check(await AudioTeardown.wait_for_release(self, refs), "snapshot fixture audio retires")

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
