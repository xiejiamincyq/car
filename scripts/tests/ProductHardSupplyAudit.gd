extends "res://tests/test_dynamic_pickup_smoke.gd"

# Test-only questions: did the requested input occur, what resources were
# actually collected, and why did the real run stop? No formal save/telemetry.
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Cars = preload("res://scripts/catalog/vehicle_catalog.gd")
const HARD_SEEDS := [611, 2026, 9001]
const SCENARIOS := ["brake_repass", "skip_first_fuel", "hull30", "overdrive_brake"]
var active_scenario := ""
var passed_during_brake: Dictionary = {}

static func build_cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for track in Tracks.all():
		for car in Cars.all():
			for scenario in SCENARIOS:
				for seed in HARD_SEEDS:
					result.append({"case_id":"%s/%s/%s/seed%d" % [track.id,car.id,scenario,seed],
						"track_id":String(track.id),"vehicle_id":String(car.id),"scenario":scenario,"run_seed":seed,
						"difficulty_index":2,"initial_hull_fixture":30.0 if scenario == "hull30" else 100.0,"budget_seconds":120.0})
	return result

static func missing_input_goals(scenario: String, observed: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	match scenario:
		"brake_repass":
			if observed.brake_deceleration_frames <= 0: missing.append("actual_brake_deceleration")
			if observed.same_vehicle_repasses <= 0: missing.append("same_vehicle_repass")
		"skip_first_fuel":
			if observed.skip_outcome != "recycled" or observed.avoid_input_frames <= 0: missing.append("deliberate_first_fuel_miss")
		"hull30":
			if observed.critical_frames <= 0: missing.append("critical_hull_driving")
			if observed.repair_effective <= 0.0: missing.append("natural_effective_repair")
		"overdrive_brake":
			if observed.overdrive_activations <= 0: missing.append("actual_overdrive_activation")
			if not observed.overdrive_ended or observed.post_overdrive_brake_frames <= 0 or observed.brake_deceleration_frames <= 0: missing.append("actual_post_overdrive_braking")
		_: missing.append("unknown_scenario")
	return missing

static func suitable_repass_target(y: float, world_speed: float, collided: bool, player_y: float, maximum_speed: float) -> bool:
	return y > player_y - 180.0 and y < player_y and world_speed < maximum_speed * 0.6 and not collided

static func select_cases(arguments: PackedStringArray) -> Array[Dictionary]:
	var cases := build_cases()
	if arguments.is_empty(): return cases
	if arguments == PackedStringArray(["--pilot"]):
		return cases.filter(func(sample): return sample.track_id == "neon_coast" and sample.vehicle_id == "pulse_gt" and sample.run_seed == 611)
	if arguments.size() != 2 or arguments[0] != "--shard" or not arguments[1].is_valid_int(): return []
	var shard := arguments[1].to_int()
	if shard < 0 or shard >= 12: return []
	var selected: Array[Dictionary] = []
	for index in range(cases.size()):
		if index % 12 == shard: selected.append(cases[index])
	return selected

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var arguments := OS.get_cmdline_user_args()
	var pilot := arguments.has("--pilot")
	var cases := select_cases(arguments)
	if cases.is_empty():
		push_error("HARD_SUPPLY_INVALID_ARGS expected no args, --pilot, or --shard 0..11")
		quit(2)
		return
	var metadata := _source_metadata()
	var rows: Array[Dictionary] = []
	var folder := "res://tmp/product-hard-supply-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(folder) == OK, "local evidence folder can be created")
	var started := Time.get_ticks_usec()
	print("HARD_SUPPLY_CONFIG ", JSON.stringify({"planned":cases.size(),"full_planned":288,"pilot":pilot,"arguments":Array(arguments),"source":metadata,
		"budget_seconds":120,"scope":"natural Main, explicit initial hull, bounded input pilot; not human win rate or independent traffic proof"}))
	for index in range(cases.size()):
		var sample: Dictionary = cases[index]
		active_scenario = sample.scenario
		passed_during_brake.clear()
		# Main's ready registers driving actions. The inherited sample releases
		# them at teardown; do not release nonexistent actions before first ready.
		_physical_forward(false)
		var start := Time.get_ticks_usec()
		var row: Dictionary = await _sample_configuration([sample.track_id,sample.vehicle_id,sample.run_seed], index, 2, sample.initial_hull_fixture, 120.0, sample.case_id)
		_physical_forward(false) # Retire a held edge even if a terminal preceded key-up.
		row.scenario = sample.scenario
		row.wall_seconds = (Time.get_ticks_usec() - start) / 1000000.0
		row.input_observed.repair_effective = row.repair_effective
		row.coverage_missing = missing_input_goals(sample.scenario, row.input_observed)
		for key in ["pre_speed","pre_collisions","pre_active","skip_target_x","skip_target_y","brake_until","brake_retry_after"]:
			row.erase(key)
		rows.append(row)
		print("HARD_SUPPLY_SAMPLE ", JSON.stringify(row))
	_check(_source_metadata() == metadata, "HEAD and sources remain frozen across the audit")
	var incomplete := rows.filter(func(row): return not row.coverage_missing.is_empty()).size()
	var summary := {"planned":cases.size(),"completed":rows.size(),"pilot":pilot,"arguments":Array(arguments),"source":metadata,"rows":rows,
		"coverage_incomplete":incomplete,"oracle_failures":failures,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0}
	var output := FileAccess.open(folder + "/summary.json",FileAccess.WRITE)
	_check(output != null, "summary can be written to local evidence")
	if output != null:
		output.store_string(JSON.stringify(summary,"\t"))
		output.close()
	for failure in failures: push_error("HARD_SUPPLY_ORACLE " + failure)
	print("HARD_SUPPLY_COMPLETE ", JSON.stringify({"planned":cases.size(),"completed":rows.size(),"coverage_incomplete":incomplete,
		"oracle_failures":failures.size(),"wall_seconds":summary.wall_seconds,"folder":ProjectSettings.globalize_path(folder)}))
	quit(1 if not failures.is_empty() else (2 if incomplete > 0 else 0))

func _source_metadata() -> Dictionary:
	var result := super._source_metadata()
	result.hard_audit_sha256 = FileAccess.get_sha256("res://scripts/tests/ProductHardSupplyAudit.gd")
	for path in ["res://scripts/impact_model.gd","res://scripts/lane_event_director.gd"]:
		result.production_sha256[path] = FileAccess.get_sha256(path)
	return result

func _apply_directed_input(main, stats: Dictionary) -> void:
	if not stats.has("input_observed"):
		stats.input_observed = {"brake_deceleration_frames":0,"same_vehicle_repasses":0,"skip_outcome":"unseen","avoid_input_frames":0,
			"critical_frames":0,"repair_effective":0.0,"overdrive_activations":0,"overdrive_ended":false,"post_overdrive_brake_frames":0}
		var car := Cars.get_by_id(StringName(stats.vehicle))
		var track := Tracks.get_by_id(StringName(stats.track))
		_check(main.drive.max_speed == car.max_speed and main.drive.acceleration == car.acceleration and main.drive.braking == car.braking,
			"actual chosen car speed, acceleration and brake applied")
		_check(absf(main.drive.steering_speed - car.steering_speed * track.steering_multiplier) < 0.001,
			"actual chosen car and track steering applied")
		_check(main.run.progression.finish_distance == track.finish_distance, "actual selected finish applied")
		_check(main.run.fuel_drain_per_second == main.run.base_fuel_drain_per_second * 2.0 and main.fuel_spawn_director.spawn_interval == 8.0 and main.repair_supplies.spawner.spawn_interval == 14.0,
			"actual hard fuel multiplier and supply intervals applied")
		stats.runtime_config = {"maximum_speed_internal":main.drive.max_speed,"acceleration":main.drive.acceleration,"braking":main.drive.braking,
			"steering":main.drive.steering_speed,"finish_distance":main.run.progression.finish_distance,"fuel_drain":main.run.fuel_drain_per_second,
			"fuel_interval":main.fuel_spawn_director.spawn_interval,"repair_interval":main.repair_supplies.spawner.spawn_interval}
		_check(main.run.fuel == 100.0 and main.integrity.current == stats.initial_hull_fixture, "only declared initial hull differs from healthy resources")
		stats.input_counts = {"accelerate":0,"brake":0,"coast":0,"safety_override":0,"steering":0}
		stats.input_events = []
		stats.skip_target_id = 0
		stats.skip_target_x = 0.0
		stats.skip_target_y = -90.0
		stats.brake_until = 0.0
		stats.brake_retry_after = 6.0
		stats.brake_attempts = 0
		stats.last_input = {}
	stats.pre_speed = main.drive.speed
	stats.pre_collisions = main.run.collisions
	stats.pre_active = main.overdrive.is_active()
	stats.pre_traffic = _npc_positions(main)
	if main.integrity.current <= 30.0: stats.input_observed.critical_frames += 1
	_apply_adverse_input(main, stats)

func _npc_positions(main) -> Dictionary:
	var result := {}
	for npc in main.traffic.vehicles:
		result["%d/%d" % [npc.get_instance_id(),npc.motion_generation]] = {"y":npc.y,"collided":npc.collided_with_player}
	return result

func _validate_resources(main, before: Dictionary, contacts: Dictionary, stats: Dictionary) -> void:
	super._validate_resources(main,before,contacts,stats)
	var input: Dictionary = stats.last_input
	if input.brake and main.drive.speed < stats.pre_speed and main.run.collisions == stats.pre_collisions:
		stats.input_observed.brake_deceleration_frames += 1
		if stats.input_observed.overdrive_ended: stats.input_observed.post_overdrive_brake_frames += 1
	if stats.pre_active and not main.overdrive.is_active():
		stats.input_observed.overdrive_ended = true
		stats.input_events.append({"event":"overdrive_ended","seconds":main.run.elapsed_seconds})
	if not stats.pre_active and main.overdrive.is_active():
		stats.input_observed.overdrive_activations += 1
		stats.input_events.append({"event":"overdrive_activated","seconds":main.run.elapsed_seconds,"fuel":main.run.fuel})
	var now := _npc_positions(main)
	var player_y: float = main.TrackGeometry.player_y(720.0)
	for identity in now:
		if not stats.pre_traffic.has(identity) or now[identity].collided: continue
		var old: Dictionary = stats.pre_traffic[identity]
		if old.collided: continue
		if old.y >= player_y and now[identity].y < player_y and input.brake:
			passed_during_brake[identity] = true
			stats.input_events.append({"event":"npc_passed_during_brake","seconds":main.run.elapsed_seconds,"npc_generation":identity})
		if old.y <= player_y and now[identity].y > player_y and passed_during_brake.has(identity):
			passed_during_brake.erase(identity)
			stats.input_observed.same_vehicle_repasses += 1
			stats.input_events.append({"event":"same_npc_repassed","seconds":main.run.elapsed_seconds,"npc_generation":identity})
	stats.erase("pre_traffic")

func _observe_pickups(previous: Array, births: Array, remaining: Array, kind: String, stage: Dictionary, stats: Dictionary) -> int:
	var contacts := super._observe_pickups(previous,births,remaining,kind,stage,stats)
	if kind != "fuel" or active_scenario != "skip_first_fuel": return contacts
	if stats.skip_target_id == 0 and not births.is_empty():
		stats.skip_target_id = births[0].get_instance_id()
		stats.input_events.append({"event":"first_fuel_selected_to_skip","seconds":stats.oracle_frames*DT,"identity":stats.skip_target_id,"lane":births[0].lane})
	for pickup in previous + births:
		if pickup.get_instance_id() != stats.skip_target_id: continue
		stats.skip_target_x = (float(pickup.lane)-1.0)*260.0
		stats.skip_target_y = pickup.y
		stats.input_observed.skip_outcome = _pickup_outcome(pickup,remaining,kind,stage)
		if not remaining.has(pickup):
			stats.input_events.append({"event":"skip_target_removed","outcome":stats.input_observed.skip_outcome,"seconds":stats.oracle_frames*DT})
	return contacts

func _apply_adverse_input(main, stats: Dictionary) -> void:
	var seconds: float = main.run.elapsed_seconds
	var player_y: float = main.TrackGeometry.player_y(720.0)
	var authority: float = main.drive.steering_speed * main.drive.speed_steering_multiplier() * main.integrity.steering_multiplier()
	var target_x: float = main.drive.lateral_position
	var pickups: Array = main.coin_director.coins
	if main.integrity.current < 70.0: pickups = main.repair_supplies.pickups
	elif main.run.fuel < 60.0: pickups = main.fuel_pickups
	var nearest_y := -INF
	for pickup in pickups:
		if pickup.get_instance_id() == stats.skip_target_id: continue
		if pickup.y < 0.0 or pickup.y > player_y + 30.0 or pickup.y < nearest_y: continue
		nearest_y = pickup.y
		target_x = (pickup.lane_position - 1.0) * 260.0 if pickup is CoinPickup else (float(pickup.lane) - 1.0) * 260.0
	var goal_skip: bool = active_scenario == "skip_first_fuel" and stats.skip_target_id != 0 and stats.input_observed.skip_outcome == "live"
	if goal_skip:
		target_x = -260.0 if stats.skip_target_x >= 0.0 else 260.0
		stats.input_observed.avoid_input_frames += 1
	if active_scenario == "brake_repass" and stats.input_observed.same_vehicle_repasses == 0 and seconds >= stats.brake_retry_after and stats.brake_attempts < 3:
		for npc in main.traffic.vehicles:
			if suitable_repass_target(npc.y,npc.actual_world_speed,npc.collided_with_player,player_y,main.drive.max_speed):
				stats.brake_until = seconds + minf(3.5, main.drive.speed / main.drive.braking + 1.5)
				stats.brake_retry_after = seconds + 12.0
				stats.brake_attempts += 1
				stats.input_events.append({"event":"planned_brake_to_let_npc_pass","seconds":seconds,"npc_generation":"%d/%d" % [npc.get_instance_id(),npc.motion_generation]})
				break
	var planned_brake: bool = seconds < stats.brake_until or (active_scenario == "overdrive_brake" and frame_index >= 840 and frame_index < 945)
	var target_speed: float = (main.drive.max_speed + main.overdrive.speed_limit_bonus()) * main.integrity.max_speed_multiplier() * (0.65 if main.run.fuel < 25.0 else 0.85)
	var planned_forward: bool = not planned_brake and main.drive.speed < target_speed
	var acceleration: float = -main.drive.braking if planned_brake else (main.drive.acceleration + (Config.OVERDRIVE_ACCELERATION_BONUS if main.overdrive.is_active() else 0.0) if planned_forward else -main.drive.rolling_resistance)
	var obstacles: Array = []
	for npc in main.traffic.vehicles:
		obstacles.append({"x":(npc.lane_position-1.0)*260.0,"y":npc.y,"speed":npc.actual_world_speed,"vx":npc.lateral_velocity,
			"target_x":(float(npc.target_lane)-1.0)*260.0 if npc.lane_change_enabled else (npc.lane_position-1.0)*260.0})
	for core in main.traffic.lane_events.core_markers(720.0):
		obstacles.append({"x":(core.x-1.5)*260.0,"y":core.y,"speed":0.0,"vx":0.0,"target_x":(core.x-1.5)*260.0,
			"half_x":260.0*Config.LANE_EVENT_CORE_HALF_LANE_RATIO+35.0,"half_y":75.0})
	if goal_skip:
		obstacles.append({"x":stats.skip_target_x,"y":stats.skip_target_y,"speed":0.0,"vx":0.0,"target_x":stats.skip_target_x,
			"half_x":68.0,"half_y":62.0}) # Driver goal veto, not a new gameplay obstacle.
	var best_score := INF
	var safe_target: float = main.drive.lateral_position
	for candidate in [target_x,main.drive.lateral_position,-330.0,-260.0,-130.0,0.0,130.0,260.0,330.0]:
		if not pilot_route_safe(main.drive.lateral_position,player_y,main.drive.speed,authority,candidate,obstacles,acceleration): continue
		var score: float = absf(candidate-target_x)+absf(candidate-main.drive.lateral_position)*0.1
		if score < best_score:
			best_score = score
			safe_target = candidate
	var steering := clampf((safe_target-main.drive.lateral_position)/maxf(1.0,authority*DT),-1.0,1.0)
	_release_input()
	# Only this requested sequence emits physical key edges; ordinary pace
	# adjustments are logical actions and cannot accidentally fake a double tap.
	if active_scenario == "overdrive_brake" and frame_index in [480,481,486,487]:
		_physical_forward(frame_index == 480 or frame_index == 486)
		stats.input_events.append({"event":"physical_forward_edge","frame":frame_index,"pressed":frame_index == 480 or frame_index == 486})
	var override_brake := is_inf(best_score)
	if planned_brake or override_brake:
		Input.action_release("accelerate")
		Input.action_press("brake")
	elif planned_forward: Input.action_press("accelerate")
	if steering > 0.0: Input.action_press("steer_right",steering)
	elif steering < 0.0: Input.action_press("steer_left",-steering)
	stats.last_input = {"planned_forward":planned_forward,"planned_brake":planned_brake,"safety_override":override_brake,
		"accelerate":Input.is_action_pressed("accelerate"),"brake":Input.is_action_pressed("brake"),"steering":steering}
	stats.input_counts["brake" if stats.last_input.brake else ("accelerate" if stats.last_input.accelerate else "coast")] += 1
	if override_brake: stats.input_counts.safety_override += 1
	if absf(steering) > 0.0: stats.input_counts.steering += 1

func _physical_forward(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
