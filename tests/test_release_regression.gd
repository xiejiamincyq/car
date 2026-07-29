extends SceneTree

const RunState = preload("res://scripts/run_state.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

const RANDOM_SEED_COUNT := 20
const STRESS_DURATION_SECONDS := 300

func _init() -> void:
	for seed in range(1, RANDOM_SEED_COUNT + 1):
		_run_seeded_regression(seed)
	_run_five_minute_stress_test()
	quit()

func _run_seeded_regression(seed: int) -> void:
	var run := RunState.new(100.0, 4.0, 30.0)
	var traffic := TrafficDirector.new(seed)
	run.start()
	for _second in range(120):
		run.tick(1.0, 560.0, 760.0)
		traffic.set_difficulty_stage(run.difficulty_stage)
		traffic.tick(1.0, 560.0, 1)
		assert(traffic.all_active_spawns_are_fair(), "Seed %d must keep every active spawn fair" % seed)
		assert(traffic.vehicles.size() <= traffic.max_active_vehicles, "Seed %d must keep active traffic bounded" % seed)
		if run.phase == RunState.Phase.ENDED:
			break
	assert(run.distance > 0.0 and run.score > 0, "Seed %d must produce a progressing run" % seed)
	traffic.reset()
	run.reset()
	assert(traffic.vehicles.is_empty() and run.phase == RunState.Phase.READY, "Seed %d reset must clear traffic and run state" % seed)
	assert(is_equal_approx(run.fuel, 100.0) and run.score == 0 and is_zero_approx(run.distance), "Seed %d reset must restore fresh-run values" % seed)

func _run_five_minute_stress_test() -> void:
	var traffic := TrafficDirector.new(20260729)
	for second in range(STRESS_DURATION_SECONDS):
		traffic.set_difficulty_stage(mini(3, second / 75))
		traffic.tick(1.0, 600.0, 1)
		assert(traffic.all_active_spawns_are_fair(), "Five-minute stress test must preserve fair active spawns at %ds" % second)
		assert(traffic.vehicles.size() <= traffic.max_active_vehicles, "Five-minute stress test must keep active traffic bounded at %ds" % second)
		assert(traffic.allocated_vehicle_count <= traffic.max_active_vehicles, "Five-minute stress test must reuse the traffic pool at %ds" % second)
