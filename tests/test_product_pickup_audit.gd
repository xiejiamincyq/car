extends SceneTree
## Small audit regressions and an isolated Main probe, no formal save access.
const Smoke = preload("res://tests/test_dynamic_pickup_smoke.gd")
const Run = preload("res://scripts/run_state.gd")
const Config = preload("res://scripts/game_config.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var run := Smoke.RunInputProbe.new(1.0, 100.0, 0.0)
	run.start()
	run.tick(1.0, 500.0, 500.0)
	_check(run.phase == Run.Phase.GAME_OVER and not run.tick_inputs.is_empty(), "Fixture is a real resource-terminal tick, not a mocked phase")
	_check(Smoke._frame_needs_audit(Run.Phase.RUNNING, run.phase), "A driving frame must be audited even when its real tick reaches terminal")
	_check(not _legacy_frame_gate(run.phase), "Negative control: old after-phase gate discards this terminal frame")
	var npc := {"y": 300.0, "cruise_speed": 900.0, "actual_world_speed": 100.0}
	var expected := 300.0 + (500.0 - 100.0) * Config.ROAD_SCROLL_MULTIPLIER * 1.3
	_check(absf(Smoke._npc_future_y(npc, 500.0) - expected) < 0.0001, "Hazard prediction uses actual braked NPC motion, not its desired cruise")
	_check(absf(_legacy_future_y(npc, 500.0) - expected) > 100.0, "Negative control: cruise prediction differs materially for the same NPC")
	var crossing := [{"x": 0.0, "y": 580.0, "speed": 200.0, "vx": 0.0, "target_x": 0.0}]
	_check(not _route_safe(-260.0, 580.0, 200.0, 540.0, 260.0, crossing), "A clear destination cannot approve crossing through the occupied middle lane")
	_check(_route_safe(-260.0, 580.0, 200.0, 540.0, -260.0, crossing), "A separated current lane remains a realizable safe route")
	var merging := [{"x": 260.0, "y": 550.0, "speed": 200.0, "vx": -624.0, "target_x": -260.0}]
	_check(not _route_safe(0.0, 580.0, 200.0, 540.0, 0.0, merging), "The pilot must account for an NPC already moving into its path")
	var ordered := Smoke.RunInputProbe.new(100.0, 0.0, 0.0)
	ordered.start()
	ordered.consume_fuel(5.0)
	ordered.add_fuel(24.0)
	ordered.consume_fuel(150.0)
	ordered.tick(1.0 / 60.0, 0.0, 500.0)
	_check(ordered.fuel == 0.0 and ordered.phase == Run.Phase.GAME_OVER, "Ordered fixture executes real capped credit and terminal depletion")
	var captured: Variant = ordered.get("events")
	_check(captured is Array and captured.size() == 4, "Transparent probe retains consume/add/consume/tick instead of only final tick inputs")
	if captured is Array and captured.size() == 4:
		_check(captured[0].kind == "consume" and captured[1].kind == "add" and captured[2].kind == "consume" and captured[3].kind == "tick", "Resource ledger keeps original call order")
		_check(captured[3].phase == Run.Phase.RUNNING and captured[3].checkpoints == 0, "Terminal tick carries input phase and checkpoint result")
	var tick := {"speed": 500.0, "maximum_speed": 500.0, "acceleration": 0.0, "drain": 100.0, "delta": 1.0, "distance": 0.0, "maximum": 100.0}
	var terminal := Smoke._fuel_tick_result(1.0, tick, [])
	_check(terminal.fuel == 0.0 and terminal.distance == 50.0, "Independent oracle still applies the fatal frame's fuel and distance")
	var checkpoint := Smoke._fuel_tick_result(1.0, tick, [25.0, 50.0])
	_check(checkpoint.checkpoints == 2 and checkpoint.fuel == Config.CHECKPOINT_FUEL_REWARD * 2, "Terminal-tick oracle credits only actual crossed thresholds after drain")
	var pickup := {"lane": 1, "y": 580.0}
	var stage := {"x": 0.0, "player_y": 580.0, "height": 720.0}
	_check(Smoke._pickup_outcome(pickup, [pickup], "fuel", {}) == "live", "Early-terminal skipped pipeline does not invent a pickup contact")
	_check(Smoke._pickup_outcome(pickup, [], "fuel", {}) == "removed_without_stage", "Skipped pipeline cannot silently remove a pickup")
	_check(Smoke._pickup_outcome(pickup, [], "fuel", stage) == "collected", "Processed strict contact is a collected object")
	_check(Smoke._pickup_outcome(pickup, [pickup], "fuel", stage) == "uncollected_contact", "Negative control catches a missed real contact")
	pickup.y = 780.0
	_check(Smoke._pickup_outcome(pickup, [], "fuel", stage) == "recycled", "Only crossing the real recycling boundary explains non-contact removal")
	pickup.y = 400.0
	_check(Smoke._pickup_outcome(pickup, [], "fuel", stage) == "unexplained_removal", "Negative control rejects arbitrary pickup disappearance")
	await _pipeline_probe()
	print("PICKUP_AUDIT_SELF_CHECK failures=%d" % failures.size())
	for failure in failures: push_error(failure)
	print("TEST_COMPLETE test_product_pickup_audit.gd")
	quit(0 if failures.is_empty() else 1)

static func _legacy_frame_gate(phase_after: int) -> bool:
	return phase_after == Run.Phase.RUNNING

static func _legacy_future_y(npc, player_speed: float) -> float:
	return npc.y + (player_speed - npc.cruise_speed) * Config.ROAD_SCROLL_MULTIPLIER * 1.3

func _route_safe(x: float, y: float, speed: float, authority: float, target: float, obstacles: Array) -> bool:
	return Smoke.pilot_route_safe(x, y, speed, authority, target, obstacles)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _pipeline_probe() -> void:
	# One ordinary real Main frame, not a route/matrix run or injected resource.
	root.size = Vector2i(1280, 720)
	var main = Smoke.MainScene.instantiate()
	main.set_script(Smoke.MainPipelineProbe)
	root.add_child(main)
	main.set_process(false)
	_check(not main.persistence_enabled and current_scene != main, "Probe scene remains outside the formal persistence gate")
	main.run = Smoke.RunInputProbe.new(main.run.max_fuel, main.run.base_fuel_drain_per_second, main.run.fuel_grace_seconds)
	main.integrity = Smoke.HullInputProbe.new()
	main.fuel_spawn_director = Smoke.FuelBirthProbe.new(611, Config.ROAD_LANE_COUNT, main.fuel_spawn_director.spawn_interval)
	main.repair_supplies.spawner = Smoke.FuelBirthProbe.new(611, Config.ROAD_LANE_COUNT, main.repair_supplies.spawner.spawn_interval)
	main.coin_director = Smoke.CoinBirthProbe.new(611, Config.ROAD_LANE_COUNT)
	Smoke.Launcher.configure_main(main, {"track_id": "neon_coast", "vehicle_id": "pulse_gt", "difficulty_index": 1, "run_seed": 611})
	for countdown_step in range(181):
		if main.run.phase != Run.Phase.COUNTDOWN: break
		main._process(Smoke.DT)
	_check(main.run.phase == Run.Phase.RUNNING, "Small fixture reaches driving via the real countdown")
	main.run.events.clear()
	main._process(Smoke.DT)
	_check(main.pickup_stages.has("fuel") and main.pickup_stages.has("repair") and main.pickup_stages.has("coins"), "Transparent scene records all actually entered pickup stages")
	_check(main.run.events.size() >= 2 and main.run.events[0].kind == "consume" and main.run.events[1].kind == "tick", "Main's ordinary resource pipeline reaches ordered probes")
	_check(not main.coin_director.accepted.is_empty(), "Birth probe observes the first naturally generated coin route")
	# Adversarial low-resource unit fixture, not one of the 30 natural sessions.
	# The already naturally born coins must remain untouched when Main's real
	# fuel-terminal tick returns before all three pickup stages.
	var coins_before: Array = main.coin_director.coins.duplicate()
	var positions_before: Array[float] = []
	for coin in coins_before: positions_before.append(coin.y)
	main.run = Smoke.RunInputProbe.new(0.001, 100.0, 0.0)
	main.run.start()
	main.pickup_stages.clear()
	main._process(Smoke.DT)
	_check(main.run.phase == Run.Phase.GAME_OVER and main.run.fuel == 0.0, "Real Main reaches an early fuel terminal in the small negative fixture")
	_check(main.run.events.size() == 2 and main.run.events[1].kind == "tick", "Main's fatal frame still records the real consume/tick inputs")
	_check(main.pickup_stages.is_empty(), "Fuel terminal does not pretend fuel/repair/coin stages were entered")
	_check(main.coin_director.coins == coins_before, "Unprocessed natural coins remain live after early terminal")
	for index in range(coins_before.size()):
		_check(coins_before[index].y == positions_before[index], "Skipped pickup pipeline does not advance old coins")
	var playbacks: Array[WeakRef] = Smoke.AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	await process_frame
	_check(await Smoke.AudioTeardown.wait_for_release(self, playbacks), "Small probe releases its audio ownership")
