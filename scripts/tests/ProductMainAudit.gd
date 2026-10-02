extends SceneTree

## Directed fixed-centre integration audit, NOT human play, a winning bot, or
## a reachable-escape proof. Only input is scripted; all world/resources are real.
const MainScene = preload("res://scenes/main.tscn")
const Launcher = preload("res://tests/PlaytestLauncher.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
const Config = preload("res://scripts/game_config.gd")
const Run = preload("res://scripts/run_state.gd")
const STEP := 1.0 / 60.0
const SEEDS := [611, 2026, 9001, 616, 618]
const TRAJECTORIES := ["accelerate", "brake_repass", "overdrive_brake"]
const SOURCE_FILES := ["res://scripts/main.gd", "res://scripts/impact_model.gd", "res://scripts/traffic_director.gd", "res://scripts/traffic_vehicle.gd", "res://scripts/traffic_safety_policy.gd", "res://scripts/lane_event_director.gd"]
var failures: Array[String] = []
var forward_down := false

# Transparent argument probes. No fake resources or alternate gameplay rules.
class RunLedger extends "res://scripts/run_state.gd":
	var events: Array[Dictionary] = []
	func consume_fuel(amount: float) -> void:
		events.append({"kind":"consume", "amount":amount})
		super.consume_fuel(amount)
	func add_fuel(amount: float) -> void:
		events.append({"kind":"add", "amount":amount, "maximum":max_fuel})
		super.add_fuel(amount)
	func tick(delta: float, speed: float, maximum_speed: float, forward_acceleration: float = 0.0) -> void:
		events.append({"kind":"tick", "delta":delta, "speed":speed, "maximum_speed":maximum_speed, "acceleration":forward_acceleration, "drain":fuel_drain_per_second})
		super.tick(delta, speed, maximum_speed, forward_acceleration)
		events[-1]["checkpoints"] = last_checkpoints_crossed

class HullLedger extends "res://scripts/vehicle_integrity.gd":
	var events: Array[Dictionary] = []
	func apply_damage(amount: float) -> Dictionary:
		events.append({"kind":"damage", "amount":amount})
		return super.apply_damage(amount)
	func repair(amount: float) -> float:
		events.append({"kind":"repair", "amount":amount, "maximum":100.0})
		return super.repair(amount)

func _init() -> void:
	# Preloading this script for its static self-check functions does not run it.
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var pilot := OS.get_cmdline_user_args().has("--pilot")
	var folder := "res://tmp/product-main-audit-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Cannot create audit output directory")
		quit(2)
		return
	var stamp := Time.get_datetime_string_from_system(true)
	var hashes_before := _source_hashes()
	var results: Array[Dictionary] = []
	print("PRODUCT_MAIN_AUDIT_CONFIG ", JSON.stringify({"timestamp_utc":stamp, "source_sha256":hashes_before, "pilot":pilot, "step":STEP, "budget_running_seconds":120, "input":"real released physical W edges; fixed-centre, no avoidance", "scope":"directed Main integration; no resource/world injection or real save I/O; traffic is under active development; NOT R2 acceptance or fairness proof"}))
	for seed in SEEDS:
		for trajectory in TRAJECTORIES:
			var result: Dictionary = await _sample(seed, trajectory, folder)
			results.append(result)
			print("PRODUCT_MAIN_AUDIT_SAMPLE ", JSON.stringify(result))
		if pilot: break
	var summary := {"timestamp_utc":stamp, "source_sha256_before":hashes_before, "source_sha256_after":_source_hashes(), "results":results, "fixture_failures":failures, "scope":"observations only; not visual or reachable-escape acceptance"}
	var output := FileAccess.open(folder + "/summary.json", FileAccess.WRITE)
	if output == null:
		_check(false, "Cannot open summary output")
	else:
		output.store_string(JSON.stringify(summary, "\t"))
		output.close()
	print("PRODUCT_MAIN_AUDIT_COMPLETE cases=%d fixture_failures=%d folder=%s" % [results.size(), failures.size(), ProjectSettings.globalize_path(folder)])
	quit(0 if failures.is_empty() else 1)

func _sample(seed: int, trajectory: String, folder: String) -> Dictionary:
	var main = MainScene.instantiate()
	root.add_child(main) # Never current_scene: _ready's formal persistence gate stays off.
	main.set_process(false)
	_check(not main.persistence_enabled, "Main _ready must not open formal persistence")
	main.run = RunLedger.new(main.run.max_fuel, main.run.base_fuel_drain_per_second, main.run.fuel_grace_seconds)
	main.integrity = HullLedger.new()
	Launcher.configure_main(main, {"track_id":"neon_coast", "vehicle_id":"pulse_gt", "difficulty_index":1, "run_seed":seed})
	for countdown_step in range(181):
		if main.run.phase != Run.Phase.COUNTDOWN: break
		main._process(STEP)
	_check(main.run.phase == Run.Phase.RUNNING, "Real countdown reaches driving phase")
	_check(main.run.fuel == main.run.max_fuel and main.integrity.current == 100.0, "Real healthy starting resources retained")
	var stats := {"seed":seed, "trajectory":trajectory, "initial":_state(main), "frames":0, "ledger_frames":0, "terminal_frame_checked":false, "brake_frames":0, "brake_deceleration_frames_without_collision":0, "repass_after_brake":0, "overdrive_activations":0, "overdrive_attempts":[], "natural_fuel_pickups":0, "natural_repairs":0, "damage_events":0, "player_swept_contact_frames":0, "player_endpoint_clear_crossing_frames":0, "npc_body_swept_frames":0, "npc_endpoint_penetration_frames":0, "npc_endpoint_clear_crossing_frames":0, "sweep_samples":[], "brake_events":[], "repass_events":[]}
	var log := FileAccess.open(folder + "/%d-%s.jsonl" % [seed, trajectory], FileAccess.WRITE)
	_check(log != null, "Frame ledger output opens")
	var braked := false
	var brake_finished := false
	var previous_brake := false
	for step in range(7200):
		if main.run.phase != Run.Phase.RUNNING: break
		var before := _state(main)
		var npc_before := _npc_snapshot(main)
		var input := trajectory_input(trajectory, step)
		var active_before_input: bool = main.overdrive.is_active()
		_set_forward(input.forward)
		Input.action_press("brake") if input.brake else Input.action_release("brake")
		_check(Input.is_action_pressed("accelerate") == input.forward, "Physical forward edges update the real Main driving action")
		if trajectory == "overdrive_brake" and step % 1800 == 486:
			stats.overdrive_attempts.append({"seconds":step * STEP, "fuel":main.run.fuel, "activated":main.overdrive.is_active(), "controller_state":main.overdrive.state})
		if not active_before_input and main.overdrive.is_active(): stats.overdrive_activations += 1
		main.run.events.clear()
		main.integrity.events.clear()
		main._process(STEP)
		var after := _state(main)
		# Observe and validate BEFORE checking terminal state: no lost final frame.
		_validate_ledger(main, before, stats)
		_observe_sweeps(main, npc_before, before, after, stats)
		if input.brake:
			stats.brake_frames += 1
			if after.speed < before.speed - 0.00001 and after.collisions == before.collisions:
				stats.brake_deceleration_frames_without_collision += 1
				if not braked: stats.brake_events.append({"seconds":after.seconds, "speed_before":before.speed, "speed_after":after.speed})
				braked = true
		if previous_brake and not input.brake: brake_finished = true
		if brake_finished and braked and after.overtakes > before.overtakes:
			stats.repass_after_brake += after.overtakes - before.overtakes
			stats.repass_events.append({"seconds":after.seconds, "count":after.overtakes - before.overtakes})
		previous_brake = input.brake
		stats.frames += 1
		if log != null:
			log.store_line(JSON.stringify({"frame":step, "input":input, "before":before, "after":after, "fuel_ledger":main.run.events, "hull_ledger":main.integrity.events}))
		if main.run.phase != Run.Phase.RUNNING:
			stats.terminal_frame_checked = true
			break
	stats.final = _state(main)
	stats.coverage = coverage(trajectory, braked, stats.repass_after_brake > 0, stats.overdrive_activations > 0)
	stats.coverage.natural_fuel_credit = "observed" if stats.natural_fuel_pickups > 0 else "insufficient"
	stats.coverage.natural_repair_credit = "observed" if stats.natural_repairs > 0 else "insufficient"
	stats.coverage.collision = "observed" if main.run.collisions > 0 else "insufficient"
	stats.coverage.finish = "observed" if main.run.phase == Run.Phase.RUN_CLEAR else "insufficient"
	stats.stop_reason = "budget" if main.run.phase == Run.Phase.RUNNING else "real_terminal"
	if main.run.phase == Run.Phase.RUN_CLEAR:
		_check(main.run.distance >= main.run.progression.finish_distance, "Real finish terminal reaches selected track distance")
	elif main.run.phase == Run.Phase.GAME_OVER:
		_check((main.run.failure_reason == &"integrity" and main.integrity.current < 20.0) or (main.run.failure_reason == &"fuel" and main.run.fuel <= 0.0 and main.run.elapsed_seconds >= main.run.fuel_grace_seconds), "Real failure terminal is justified by actual resources")
	stats.fixture_failures_so_far = failures.size()
	if log != null: log.close()
	_set_forward(false)
	for action in ["accelerate", "brake", "steer_left", "steer_right"]: Input.action_release(action)
	var playbacks: Array[WeakRef] = AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, playbacks), "Audit audio playbacks retire before the next session/exit")
	return stats

func _set_forward(pressed: bool) -> void:
	if pressed == forward_down: return
	forward_down = pressed
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events() # Dispatches to Main._input and updates actual action state.

func _validate_ledger(main, before: Dictionary, stats: Dictionary) -> void:
	var expected_fuel: float = before.fuel
	var ticks := 0
	for event in main.run.events:
		if event.kind == "tick":
			ticks += 1
			var ratio := clampf(event.speed / maxf(1.0, event.maximum_speed), 0.0, 1.0)
			var load := Config.FUEL_ROLLING_RESISTANCE_LOAD * clampf(ratio / Config.FUEL_ROLLING_RESISTANCE_FULL_SPEED_RATIO, 0.0, 1.0)
			load += Config.FUEL_AERODYNAMIC_RESISTANCE_LOAD * ratio * ratio
			load += Config.FUEL_ACCELERATION_LOAD * minf(maxf(0.0, event.acceleration) / Config.ACCELERATION, 1.25)
			expected_fuel = maxf(0.0, expected_fuel - event.drain * load * event.delta)
			var checkpoint_count := 0
			var end_distance: float = before.distance + maxf(0.0, event.speed) * event.delta * 0.1
			for checkpoint in main.run.progression.checkpoint_distances:
				if checkpoint > before.distance and checkpoint <= end_distance: checkpoint_count += 1
			_check(checkpoint_count == event.checkpoints, "Checkpoint ledger matches actual distance thresholds")
			expected_fuel = minf(main.run.max_fuel, expected_fuel + checkpoint_count * Config.CHECKPOINT_FUEL_REWARD)
		else:
			expected_fuel = ledger_value(expected_fuel, event)
			if event.kind == "add" and event.amount > 0.0: stats.natural_fuel_pickups += 1
	_check(ticks == 1, "Every driving frame including terminal executes exactly one resource tick")
	_check(absf(expected_fuel - main.run.fuel) < 0.001, "Fuel equals ordered real consume/drain/checkpoint/pickup ledger")
	var expected_hull: float = before.integrity
	var damage_count := 0
	for event in main.integrity.events:
		expected_hull = ledger_value(expected_hull, event)
		if event.kind == "damage":
			damage_count += 1
		elif event.amount > 0.0:
			stats.natural_repairs += 1
	_check(absf(expected_hull - main.integrity.current) < 0.001, "Integrity equals ordered real damage/repair ledger")
	_check(damage_count == main.run.collisions - before.collisions, "Each counted impact has one actual damage entry")
	stats.damage_events += damage_count
	stats.ledger_frames += 1

func _state(main) -> Dictionary:
	return {"seconds":main.run.elapsed_seconds, "phase":Run.Phase.keys()[main.run.phase], "failure_reason":String(main.run.failure_reason), "distance":main.run.distance, "finish_distance":main.run.progression.finish_distance, "fuel":main.run.fuel, "integrity":main.integrity.current, "speed":main.drive.speed, "x":main.drive.lateral_position, "lateral_velocity":main.lateral_velocity, "steering_authority":main.drive.steering_speed * main.drive.speed_steering_multiplier() * main.integrity.steering_multiplier(), "collisions":main.run.collisions, "overtakes":main.run.overtakes, "coins":main.run.coins, "score":main.run.score, "overdrive_active":main.overdrive.is_active()}

func _npc_snapshot(main) -> Dictionary:
	var result := {}
	var width := Config.ROAD_HALF_WIDTH * 2.0 / Config.ROAD_LANE_COUNT
	for npc in main.traffic.vehicles:
		var id := "%d:%d" % [npc.get_instance_id(), npc.motion_generation]
		result[id] = {"x":(npc.lane_position - 1.0) * width, "y":npc.y, "half_width":npc.half_width, "half_length":npc.half_length, "actual_speed":npc.actual_world_speed, "kind":npc.kind, "warning":npc.warning_started, "target_lane":npc.target_lane, "collided_with_player":npc.collided_with_player}
	return result

func _observe_sweeps(main, before: Dictionary, player_before: Dictionary, player_after: Dictionary, stats: Dictionary) -> void:
	var after := _npc_snapshot(main)
	var player_y: float = main.TrackGeometry.player_y(main.get_viewport_rect().size.y)
	var identities := after.keys()
	for i in range(identities.size()):
		var id = identities[i]
		if not before.has(id): continue # New/recycled body is not a swept segment.
		var old: Dictionary = before[id]
		var now: Dictionary = after[id]
		var extents := Vector2(Config.COLLISION_LATERAL_DISTANCE + now.half_width - 25.0, Config.COLLISION_LONGITUDINAL_DISTANCE + now.half_length - 42.0)
		var start := Vector2(old.x - player_before.x, old.y - player_y)
		var end := Vector2(now.x - player_after.x, now.y - player_y)
		if swept_contact(start, end, extents):
			stats.player_swept_contact_frames += 1
			if not _inside(start, extents) and not _inside(end, extents):
				stats.player_endpoint_clear_crossing_frames += 1
				_record_sweep(stats, {"kind":"player_two_clear_endpoints_crossing", "seconds":player_after.seconds, "input_policy":"fixed-centre, no avoidance; not unfairness attribution", "start":[start.x,start.y], "end":[end.x,end.y], "gameplay_extents":[extents.x,extents.y], "npc":now})
		for j in range(i + 1, identities.size()):
			var other_id = identities[j]
			if not before.has(other_id): continue
			var other_old: Dictionary = before[other_id]
			var other_now: Dictionary = after[other_id]
			var pair_start := Vector2(old.x - other_old.x, old.y - other_old.y)
			var pair_end := Vector2(now.x - other_now.x, now.y - other_now.y)
			var bodies := Vector2(now.half_width + other_now.half_width, now.half_length + other_now.half_length)
			if not swept_contact(pair_start, pair_end, bodies): continue
			stats.npc_body_swept_frames += 1
			var penetration := _inside(pair_end, bodies)
			stats.npc_endpoint_penetration_frames += 1 if penetration else 0
			var crossing := not _inside(pair_start, bodies) and not penetration
			stats.npc_endpoint_clear_crossing_frames += 1 if crossing else 0
			_record_sweep(stats, {"kind":"npc_body_sweep", "seconds":player_after.seconds, "endpoint_penetration":penetration, "both_endpoints_clear":crossing, "player_contact_history":now.collided_with_player or other_now.collided_with_player, "first":now, "second":other_now, "start":[pair_start.x,pair_start.y], "end":[pair_end.x,pair_end.y]})

static func _inside(point: Vector2, extents: Vector2) -> bool:
	return absf(point.x) < extents.x and absf(point.y) < extents.y

func _record_sweep(stats: Dictionary, event: Dictionary) -> void:
	if stats.sweep_samples.size() < 20: stats.sweep_samples.append(event)

func _source_hashes() -> Dictionary:
	var hashes := {}
	for path in SOURCE_FILES: hashes[path] = FileAccess.get_sha256(path)
	return hashes

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error("PRODUCT_MAIN_AUDIT " + message)

static func swept_contact(start: Vector2, end: Vector2, extents: Vector2) -> bool:
	# Open-box slab intersection: strict body penetration, not tangency.
	var enter := 0.0
	var leave := 1.0
	for axis in range(2):
		var movement: float = end[axis] - start[axis]
		if absf(movement) < 0.000001:
			if absf(start[axis]) >= extents[axis]: return false
		else:
			var first: float = (-extents[axis] - start[axis]) / movement
			var last: float = (extents[axis] - start[axis]) / movement
			enter = maxf(enter, minf(first, last))
			leave = minf(leave, maxf(first, last))
	return enter < leave

static func trajectory_input(trajectory: String, step: int) -> Dictionary:
	var cycle := step % 1800
	var forward := true
	var brake := false
	if trajectory == "brake_repass":
		brake = cycle >= 600 and cycle < 675
		forward = not (cycle >= 600 and cycle < 840)
	elif trajectory == "overdrive_brake":
		brake = cycle >= 840 and cycle < 930
		forward = not (cycle >= 840 and cycle < 1080)
		# Release before both physical press edges; keep the second held.
		if cycle == 479 or (cycle >= 481 and cycle < 486): forward = false
	return {"forward": forward, "brake": brake}

static func coverage(trajectory: String, braked: bool, repassed: bool, activated: bool) -> Dictionary:
	return {"brake":"not_requested" if trajectory == "accelerate" else ("observed" if braked else "insufficient"), "repass":"not_requested" if trajectory == "accelerate" else ("observed" if repassed else "insufficient"), "overdrive":"not_requested" if trajectory != "overdrive_brake" else ("observed" if activated else "insufficient")}

static func ledger_value(before: float, event: Dictionary) -> float:
	match event.kind:
		"consume", "damage": return maxf(0.0, before - maxf(0.0, event.amount))
		"repair": return before if before < 20.0 else minf(event.maximum, before + maxf(0.0, event.amount))
		"add": return minf(event.maximum, before + maxf(0.0, event.amount))
	return before
