extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
var failures: Array[String] = []

func _init() -> void:
	for seed in [3, 7]:
		for initial_lane in 3:
			for target_speed in [360.0, 560.0, 760.0]:
				_run_case(seed, initial_lane, target_speed)
				if not failures.is_empty():
					break
			if not failures.is_empty():
				break
		if not failures.is_empty():
			break
	for failure in failures:
		push_error("FAST_ARRIVAL_CORRIDOR " + failure)
	print("FAST_ARRIVAL_CORRIDOR failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_fast_arrival_corridor.gd")
	quit(0 if failures.is_empty() else 1)

func _run_case(seed: int, initial_lane: int, target_speed: float) -> void:
	var traffic := Traffic.new(seed, Config.ROAD_LANE_COUNT, Config.MIN_SPAWN_DISTANCE, Config.MIN_TRAFFIC_GAP)
	traffic.set_viewport_height(1080.0)
	var lane := initial_lane
	var speed := target_speed
	var history: Array[Dictionary] = []
	for step in 240:
		var elapsed: float = step * 0.25
		var target: float = target_speed
		traffic.set_difficulty_stage(mini(3, int(elapsed / 15.0)))
		traffic.tick(0.25, speed, lane)
		var vehicles: Array[Dictionary] = []
		for vehicle in traffic.vehicles:
			vehicles.append({"kind":vehicle.kind,"lane":vehicle.lane,"target":vehicle.target_lane,"y":vehicle.y,"speed":vehicle.actual_world_speed,"cruise":vehicle.cruise_speed,"warning":vehicle.warning_started,"moving":vehicle.change_started,"arrival_warning":vehicle.arrival_warning_started,"overtake_remaining":vehicle.overtake_warning_remaining})
		history.append({"step":step,"player_speed":speed,"player_lane":lane,"state":traffic.lane_events.state,"closed":traffic.lane_events.closed_lanes(),"cores":traffic.lane_events.core_markers(1080.0),"vehicles":vehicles})
		if history.size() > 7:
			history.pop_front()
		var immediate: Array[int] = traffic.reachable_player_lanes(lane, Geometry.player_y(1080.0), Config.COLLISION_LONGITUDINAL_DISTANCE)
		if immediate.is_empty():
			for sample in history:
				print("FAST_ARRIVAL_CORRIDOR_WITNESS ", JSON.stringify(sample))
			failures.append("Competing fast arrivals must preserve immediate player escape at step %d, seed %d initial lane %d target speed %.0f" % [step, seed, initial_lane, target_speed])
			break
		var reachable: Array[int] = traffic.reachable_player_lanes(lane, Geometry.player_y(1080.0), traffic.braking_reaction_clearance(target))
		if reachable.is_empty():
			speed = maxf(0.0, speed - Config.BRAKING * 0.25)
		elif not reachable.has(lane):
			var closest: int = reachable[0]
			for candidate in reachable:
				if abs(candidate - lane) < abs(closest - lane): closest = candidate
			lane = closest
		else:
			speed = minf(target, speed + Config.ACCELERATION * 0.25)
		if traffic.has_full_lane_wall() or traffic.has_vehicle_overlap():
			failures.append("Original wall120 and physical body safety remain intact")
			break
