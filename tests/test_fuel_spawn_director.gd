extends SceneTree

const FuelSpawnDirector = preload("res://scripts/fuel_spawn_director.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const RunState = preload("res://scripts/run_state.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	var pickup_supply_per_second := GameConfig.FUEL_PICKUP_AMOUNT / GameConfig.FUEL_PICKUP_INTERVAL
	var previous_drain := 0.0
	for speed in [280.0, 560.0, 760.0]:
		var run := RunState.new(100.0, GameConfig.FUEL_DRAIN_PER_SECOND, 0.0)
		run.start()
		run.tick(1.0, speed, GameConfig.MAX_SPEED)
		var actual_drain := 100.0 - run.fuel
		assert(actual_drain > previous_drain, "Steady fuel consumption must rise with speed %.0f" % speed)
		assert(pickup_supply_per_second > actual_drain, "A collected pickup must provide a meaningful recovery at speed %.0f" % speed)
		previous_drain = actual_drain

	var reproducible_a := FuelSpawnDirector.new(77, 3, GameConfig.FUEL_PICKUP_INTERVAL)
	var reproducible_b := FuelSpawnDirector.new(77, 3, GameConfig.FUEL_PICKUP_INTERVAL)
	var sequence_a: Array[int] = []
	var sequence_b: Array[int] = []
	for _spawn_index in range(6):
		sequence_a.append(reproducible_a.tick(GameConfig.FUEL_PICKUP_INTERVAL, [], 1).lane)
		sequence_b.append(reproducible_b.tick(GameConfig.FUEL_PICKUP_INTERVAL, [], 1).lane)
	assert(sequence_a == sequence_b, "A fixed run seed must reproduce the fuel sequence")

	var varied := FuelSpawnDirector.new(78, 3, GameConfig.FUEL_PICKUP_INTERVAL)
	var varied_sequence: Array[int] = []
	for _spawn_index in range(6):
		varied_sequence.append(varied.tick(GameConfig.FUEL_PICKUP_INTERVAL, [], 1).lane)
	assert(varied_sequence != sequence_a, "Different run seeds must vary the fuel sequence")

	var safe_spawn := FuelSpawnDirector.new(10, 3, GameConfig.FUEL_PICKUP_INTERVAL)
	var only_center_safe = safe_spawn.tick(GameConfig.FUEL_PICKUP_INTERVAL, [0, 2], 1)
	assert(only_center_safe != null and only_center_safe.lane == 1, "Fuel must use the only safe reachable lane")
	var delayed = safe_spawn.tick(GameConfig.FUEL_PICKUP_INTERVAL, [0, 1, 2], 1)
	assert(delayed == null, "Fuel must delay instead of spawning into a blocked route")
	var adjacent_after_delay = safe_spawn.tick(0.5, [0, 2], 0)
	assert(adjacent_after_delay != null and adjacent_after_delay.lane == 1, "A delayed pickup must choose an adjacent reachable lane when it becomes safe")

	var traffic := TrafficDirector.new(22)
	var steady = traffic.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, FuelSpawnDirector.PICKUP_SPAWN_Y)
	traffic.vehicles.append(steady)
	var changer = traffic.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 1, FuelSpawnDirector.PICKUP_SPAWN_Y)
	changer.target_lane = 2
	changer.warning_started = true
	traffic.vehicles.append(changer)
	assert(traffic.blocked_lanes_near(FuelSpawnDirector.PICKUP_SPAWN_Y, GameConfig.FUEL_SPAWN_SAFETY_DISTANCE) == [0, 1, 2], "Fuel safety must reserve occupied and announced merge lanes")

	var bottom_spawn_y := TrackGeometry.fast_overtake_spawn_y(720.0)
	traffic.set_spawn_exclusion_zones([Vector2(1, bottom_spawn_y)])
	assert(not traffic.is_fast_spawn_fair(760.0, 1), "NPC traffic must not spawn over fuel waiting at the bottom boundary")
	traffic.set_spawn_exclusion_zones([Vector2(0, bottom_spawn_y)])
	assert(traffic.is_fast_spawn_fair(760.0, 1), "Fuel in another lane must not block a safe NPC bottom spawn")
	traffic.set_spawn_exclusion_zones([Vector2(1, bottom_spawn_y)])
	traffic.reset(22)
	assert(traffic.is_fast_spawn_fair(760.0, 1), "Restarting a run must clear stale fuel spawn exclusions")
	quit()
