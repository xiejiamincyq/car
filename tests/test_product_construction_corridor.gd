extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
var failures: Array[String] = []

class ObservedTraffic extends Traffic:
	var physical_failures: Array[String] = []
	func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
		var before: Dictionary = {}
		for vehicle in vehicles:
			before[vehicle.get_instance_id()] = {"generation":vehicle.motion_generation,"y":vehicle.y,"speed":vehicle.actual_world_speed}
		super._tick_step(delta, player_speed, player_lane, frame_start)
		for vehicle in vehicles:
			var previous: Dictionary = before.get(vehicle.get_instance_id(), {})
			if previous.is_empty() or previous.generation != vehicle.motion_generation:
				continue
			var rate: float = NPC_BRAKING if vehicle.actual_world_speed < previous.speed else NPC_ACCELERATION
			if absf(vehicle.actual_world_speed - previous.speed) > rate * delta + 0.00001:
				physical_failures.append("Corridor policy cannot assign instantaneous speed")
			if absf(vehicle.y - previous.y - (player_speed - vehicle.actual_world_speed) * Config.ROAD_SCROLL_MULTIPLIER * delta) > 0.00001:
				physical_failures.append("Corridor policy cannot teleport NPCs")

func _init() -> void:
	_admission_cases()
	var traffic := ObservedTraffic.new(10, Config.ROAD_LANE_COUNT, Config.MIN_SPAWN_DISTANCE, Config.MIN_TRAFFIC_GAP)
	traffic.set_viewport_height(720.0)
	var lane := 1
	var speed := 360.0
	var history: Array[Dictionary] = []
	for step in 240:
		traffic.set_difficulty_stage(mini(3, int(step * 0.25 / 15.0)))
		traffic.tick(0.25, speed, lane)
		var vehicles: Array[Dictionary] = []
		for vehicle in traffic.vehicles:
			vehicles.append({"kind":vehicle.kind,"lane":vehicle.lane,"target":vehicle.target_lane,"y":vehicle.y,"speed":vehicle.actual_world_speed,"cruise":vehicle.cruise_speed,"warning":vehicle.warning_started,"moving":vehicle.change_started})
		history.append({"step":step,"player_speed":speed,"player_lane":lane,"state":traffic.lane_events.state,"closed":traffic.lane_events.closed_lanes(),"cores":traffic.lane_events.core_markers(720.0),"vehicles":vehicles})
		if history.size() > 7:
			history.pop_front()
		var immediate: Array[int] = traffic.reachable_player_lanes(lane, Geometry.player_y(720.0), 72.0)
		if immediate.is_empty():
			for sample in history:
				print("CONSTRUCTION_CORRIDOR_WITNESS ", JSON.stringify(sample))
			failures.append("Published construction must retain a real immediate escape at step %d" % step)
			break
		var reachable: Array[int] = traffic.reachable_player_lanes(lane, Geometry.player_y(720.0), traffic.braking_reaction_clearance(360.0))
		if reachable.is_empty():
			speed = maxf(0.0, speed - Config.BRAKING * 0.25)
		elif not reachable.has(lane):
			lane = _closest_lane(lane, reachable)
		else:
			speed = minf(360.0, speed + Config.ACCELERATION * 0.25)
		if traffic.has_full_lane_wall() or traffic.has_vehicle_overlap():
			failures.append("Original wall120 and physical body safety remain intact")
			break
	failures.append_array(traffic.physical_failures)
	for failure in failures:
		push_error("CONSTRUCTION_CORRIDOR " + failure)
	print("CONSTRUCTION_CORRIDOR failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_construction_corridor.gd")
	quit(0 if failures.is_empty() else 1)

func _admission_cases() -> void:
	var traffic := Traffic.new(611)
	traffic.set_viewport_height(720.0)
	traffic.set_difficulty_stage(2)
	traffic._player_speed = 360.0
	traffic._player_lane = 1
	traffic.lane_events.begin_warning(2)
	traffic.lane_events._travel_distance = 500.0
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, 0.0, 200.0)
	traffic.vehicles.append(leader)
	var unsafe_fast = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 170.0)
	_check(not traffic._can_spawn_candidate(unsafe_fast, 360.0, 1), "Closed lane plus close open-lane fast birth cannot consume the last escape")
	var safe_normal = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, -620.0, 200.0)
	_check(traffic._can_spawn_candidate(safe_normal, 360.0, 1), "Construction still admits well-separated ordinary traffic")
	traffic.vehicles.clear()
	unsafe_fast.y = 400.0
	unsafe_fast.target_lane = 1
	_check(traffic._lane_change_creates_wall(unsafe_fast), "A lane-change reservation cannot occupy both remaining open lanes")
	_check(traffic._fast_lane_change_creates_wall(unsafe_fast, 1), "Fast planning must obey the same published-construction corridor")
	_check(traffic.lane_events.state == traffic.LaneEventDirector.State.WARNING and traffic.lane_events.cone_markers(720.0).size() > 0, "Admission rejection does not erase published construction")
	_check(leader.y == 0.0 and leader.lane == 1 and traffic.vehicles.is_empty(), "Admission never moves or adds existing/candidate cars")
	var current_leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, -700.0, 200.0)
	unsafe_fast.target_lane = 0
	traffic.vehicles.assign([unsafe_fast, current_leader])
	_check(not traffic._try_plan_fast_lane_change(unsafe_fast) and not unsafe_fast.warning_started, "Actual fast planner must not publish an impossible two-open-lane warning")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _closest_lane(current: int, candidates: Array[int]) -> int:
	var closest: int = candidates[0]
	for candidate in candidates:
		if abs(candidate - current) < abs(closest - current):
			closest = candidate
	return closest
