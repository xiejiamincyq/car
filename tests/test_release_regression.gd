extends SceneTree

const RunState = preload("res://scripts/run_state.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

const RANDOM_SEED_COUNT := 20
const STRESS_DURATION_SECONDS := 300
const PLAYER_SPEEDS := [360.0, 560.0, 760.0]

func _init() -> void:
	for seed in range(1, RANDOM_SEED_COUNT + 1):
		_assert_real_fuel_end_and_second_run(seed)
	_assert_difficulty_stages_and_vehicle_kinds()
	_assert_five_minute_multi_seed_stress()
	quit()

func _assert_real_fuel_end_and_second_run(seed: int) -> void:
	var run := RunState.new(100.0, 4.0, 30.0)
	var traffic := TrafficDirector.new(seed)
	run.start()
	for _second in range(120):
		run.tick(1.0, 560.0, 760.0, 1.0)
		traffic.set_difficulty_stage(run.difficulty_stage)
		traffic.tick(1.0, 560.0, 1)
		assert(traffic.all_active_spawns_are_fair(), "Seed %d must keep every actual spawn fair before fuel ends" % seed)
		if run.phase == RunState.Phase.ENDED:
			break
	assert(run.phase == RunState.Phase.ENDED, "Seed %d must reach a real fuel-ended result" % seed)
	assert(run.distance > 0.0 and run.score > 0, "Seed %d must progress before fuel ends" % seed)
	traffic.reset()
	run.reset()
	assert(traffic.vehicles.is_empty() and run.phase == RunState.Phase.READY, "Seed %d reset must clear traffic and run state" % seed)
	assert(is_equal_approx(run.fuel, 100.0) and run.score == 0 and is_zero_approx(run.distance), "Seed %d reset must restore fresh-run values" % seed)
	run.start()
	run.tick(1.0, 560.0, 760.0, 1.0)
	traffic.tick(1.0, 560.0, 1)
	assert(run.phase == RunState.Phase.RUNNING and run.distance > 0.0 and run.score > 0, "Seed %d must support a progressing second run after reset" % seed)

func _assert_difficulty_stages_and_vehicle_kinds() -> void:
	var progression := RunState.new(10000.0, 0.0, 30.0)
	var reached_stages := {}
	progression.start()
	for _second in range(120):
		progression.tick(1.0, 560.0, 760.0)
		reached_stages[progression.difficulty_stage] = true
	for stage in range(4):
		assert(reached_stages.has(stage), "High-fuel regression run must reach difficulty stage %d" % stage)
		var traffic := TrafficDirector.new(1000 + stage)
		traffic.set_difficulty_stage(stage)
		for _second in range(120):
			traffic.tick(1.0, 560.0, 1)
			assert(traffic.all_active_spawns_are_fair(), "Stage %d must keep actual spawns fair: %s" % [stage, _traffic_state(traffic)])
		var spawned_kinds := _spawned_kinds(traffic)
		assert(spawned_kinds.has(TrafficDirector.Kind.STEADY_SLOW), "Stage %d must actually spawn steady traffic" % stage)
		if stage >= 1:
			assert(spawned_kinds.has(TrafficDirector.Kind.SIGNAL_CHANGE), "Stage %d must actually spawn signal-change traffic" % stage)
		if stage >= 2:
			assert(spawned_kinds.has(TrafficDirector.Kind.FAST_OVERTAKE), "Stage %d must actually spawn fast overtake traffic" % stage)

func _assert_five_minute_multi_seed_stress() -> void:
	for seed in range(1, RANDOM_SEED_COUNT + 1):
		for player_lane in range(3):
			for player_speed in PLAYER_SPEEDS:
				var traffic := TrafficDirector.new(seed)
				var previous_spawn_count := 0
				for second in range(STRESS_DURATION_SECONDS):
					traffic.set_difficulty_stage(mini(3, second / 75))
					traffic.tick(1.0, player_speed, player_lane)
					var actual_spawn_count := _spawn_count(traffic)
					if actual_spawn_count > previous_spawn_count:
						assert(traffic.all_active_spawns_are_fair(), "Seed %d lane %d speed %.0f must be fair at each actual spawn: %s" % [seed, player_lane, player_speed, _traffic_state(traffic)])
					previous_spawn_count = actual_spawn_count
					assert(traffic.vehicles.size() <= traffic.max_active_vehicles, "Seed %d lane %d speed %.0f must keep active traffic bounded" % [seed, player_lane, player_speed])
					assert(traffic.allocated_vehicle_count <= traffic.max_active_vehicles, "Seed %d lane %d speed %.0f must reuse the traffic pool" % [seed, player_lane, player_speed])
				assert(previous_spawn_count > 8, "Seed %d lane %d speed %.0f must create more than eight actual vehicles in five minutes" % [seed, player_lane, player_speed])

func _spawn_count(traffic: TrafficDirector) -> int:
	return traffic.spawn_sequence().split("|", false).size()

func _spawned_kinds(traffic: TrafficDirector) -> Dictionary:
	var kinds := {}
	for spawn in traffic.spawn_sequence().split("|", false):
		kinds[int(spawn.split(":", false)[0])] = true
	return kinds

func _traffic_state(traffic: TrafficDirector) -> String:
	var states := PackedStringArray()
	for vehicle in traffic.vehicles:
		states.append("kind=%d lane=%d target=%d y=%.1f fair=%s" % [vehicle.kind, vehicle.lane, vehicle.target_lane, vehicle.y, vehicle.spawn_was_fair])
	return "blocked=%d [%s]" % [traffic.lane_events.blocked_lane(), "; ".join(states)]
