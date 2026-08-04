class_name TrafficDirector
extends RefCounted

const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")
const GameConfig = preload("res://scripts/game_config.gd")

enum Kind { STEADY_SLOW, SIGNAL_CHANGE, FAST_OVERTAKE, TRUCK }

var lane_count: int = 3
var minimum_spawn_distance: float = 620.0
var minimum_lane_gap: float = 180.0
var reaction_distance: float = 260.0
var max_active_vehicles: int = 8
var vehicles: Array[TrafficVehicle] = []
var _pool: Array[TrafficVehicle] = []
var allocated_vehicle_count: int = 0
var _random := RandomNumberGenerator.new()
var _initial_seed: int
var _next_kind: int = 0
var _schedule_cursor: int = 0
var _spawn_cooldown: float = 0.7
var _player_speed: float = 0.0
var _player_lane: int = 1
var _spawn_history: PackedStringArray = []
var difficulty_stage: int = 0
var lane_change_started_count: int = 0
var _viewport_height: float = 720.0

func _init(seed: int, lanes: int = 3, safe_distance: float = 620.0, lane_gap: float = 180.0) -> void:
	lane_count = lanes
	minimum_spawn_distance = safe_distance
	minimum_lane_gap = lane_gap
	_initial_seed = seed
	_random.seed = _initial_seed
	_spawn_history.clear()

func tick(delta: float, player_speed: float, player_lane: int = 1) -> void:
	_player_speed = player_speed
	_player_lane = player_lane
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_next(player_speed, player_lane)
		_spawn_cooldown = _spawn_interval_for_stage()
	for vehicle in vehicles:
		update_vehicle(vehicle, delta, player_speed)
	_recycle_offscreen_vehicles()

func acquire_vehicle(kind: int, lane: int, y: float) -> TrafficVehicle:
	var target_lane := _target_lane_for(kind, lane)
	var vehicle: TrafficVehicle
	if _pool.is_empty():
		vehicle = TrafficVehicle.new(kind, lane, y, target_lane)
		allocated_vehicle_count += 1
	else:
		vehicle = _pool.pop_back()
		vehicle.configure(kind, lane, y, target_lane)
	return vehicle

func reset(run_seed: int = -1) -> void:
	for vehicle in vehicles:
		_pool.append(vehicle)
	vehicles.clear()
	_next_kind = 0
	_schedule_cursor = 0
	_spawn_cooldown = 0.7
	if run_seed >= 0:
		_initial_seed = run_seed
	_random.seed = _initial_seed
	_spawn_history.clear()
	difficulty_stage = 0
	lane_change_started_count = 0

func set_difficulty_stage(stage: int) -> void:
	difficulty_stage = clampi(stage, 0, 3)

func set_viewport_height(viewport_height: float) -> void:
	_viewport_height = maxf(1.0, viewport_height)

func update_vehicle(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	if vehicle.kind == Kind.FAST_OVERTAKE:
		var overtake_speed := (player_speed * 0.30 + 260.0) * _speed_multiplier_for_stage()
		var staging_y := TrackGeometry.fast_overtake_staging_y(_viewport_height)
		if vehicle.y > staging_y:
			vehicle.y = maxf(staging_y, vehicle.y - overtake_speed * delta)
			if vehicle.y <= staging_y:
				vehicle.overtake_warning_remaining = 1.0
		elif vehicle.overtake_warning_remaining > 0.0:
			vehicle.overtake_warning_remaining = maxf(0.0, vehicle.overtake_warning_remaining - delta)
			if is_zero_approx(vehicle.overtake_warning_remaining) and not _can_release_fast_overtaker(vehicle):
				vehicle.overtake_warning_remaining = 0.25
		else:
			vehicle.y -= overtake_speed * delta
		return
	var relative_speed := player_speed * 0.45
	if vehicle.kind == Kind.STEADY_SLOW or vehicle.kind == Kind.TRUCK:
		relative_speed += 150.0 if vehicle.kind == Kind.TRUCK else 105.0
	else:
		relative_speed += 105.0
		if not vehicle.warning_started and vehicle.y >= 80.0:
			vehicle.warning_started = true
			vehicle.warning_remaining = lane_change_warning_duration()
		elif vehicle.warning_remaining > 0.0:
			vehicle.warning_remaining = maxf(0.0, vehicle.warning_remaining - delta)
		if is_zero_approx(vehicle.warning_remaining) and not vehicle.change_started:
			if is_lane_change_safe(vehicle):
				vehicle.change_started = true
				lane_change_started_count += 1
			else:
				vehicle.warning_remaining = 0.35
		if vehicle.change_started:
			vehicle.lane_position = move_toward(vehicle.lane_position, float(vehicle.target_lane), 2.4 * delta)
			if is_equal_approx(vehicle.lane_position, float(vehicle.target_lane)):
				vehicle.lane = vehicle.target_lane
	vehicle.y = _constrain_top_vehicle_y(vehicle, vehicle.y + relative_speed * _speed_multiplier_for_stage() * delta)

func is_lane_valid(lane: int) -> bool:
	return lane >= 0 and lane < lane_count

func is_lane_change_safe(vehicle: TrafficVehicle) -> bool:
	if not is_lane_valid(vehicle.target_lane):
		return false
	for other in vehicles:
		if other == vehicle:
			continue
		var reserves_target := other.kind == Kind.SIGNAL_CHANGE and other.warning_started and other.target_lane == vehicle.target_lane
		if (other.lane == vehicle.target_lane or reserves_target) and not vehicles_have_minimum_gap(vehicle, other):
			return false
	return true

func all_active_spawns_are_fair() -> bool:
	for vehicle in vehicles:
		if not is_lane_valid(vehicle.lane):
			return false
		if not vehicle.spawn_was_fair:
			return false
		if vehicle.kind != Kind.FAST_OVERTAKE and not _top_lane_has_minimum_gap(vehicle.lane):
			return false
	return true

func has_minimum_lane_gap(lane: int) -> bool:
	var lane_vehicles: Array[TrafficVehicle] = []
	for vehicle in vehicles:
		if vehicle.lane == lane:
			lane_vehicles.append(vehicle)
	for first_index in lane_vehicles.size():
		for second_index in range(first_index + 1, lane_vehicles.size()):
			if not vehicles_have_minimum_gap(lane_vehicles[first_index], lane_vehicles[second_index]):
				return false
	return true

func blocked_lanes_near(y: float, clearance: float) -> Array[int]:
	var blocked: Array[int] = []
	for vehicle in vehicles:
		if absf(vehicle.y - y) >= clearance + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
			continue
		if not blocked.has(vehicle.lane):
			blocked.append(vehicle.lane)
		if vehicle.kind == Kind.SIGNAL_CHANGE and vehicle.warning_started and not blocked.has(vehicle.target_lane):
			blocked.append(vehicle.target_lane)
	blocked.sort()
	return blocked

func reachable_player_lanes(player_lane: int, player_y: float, clearance: float) -> Array[int]:
	var blocked: Array[int] = []
	for vehicle in vehicles:
		if absf(vehicle.y - player_y) >= clearance + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
			continue
		if vehicle.kind == Kind.FAST_OVERTAKE and vehicle.overtake_warning_remaining > 0.0:
			continue
		if not blocked.has(vehicle.lane):
			blocked.append(vehicle.lane)
		if vehicle.kind == Kind.SIGNAL_CHANGE and vehicle.warning_started and not blocked.has(vehicle.target_lane):
			blocked.append(vehicle.target_lane)
	var reachable: Array[int] = []
	for lane in range(lane_count):
		if abs(lane - player_lane) <= 1 and not blocked.has(lane):
			reachable.append(lane)
	return reachable

func _can_release_fast_overtaker(overtaker: TrafficVehicle) -> bool:
	var player_y := TrackGeometry.player_y(_viewport_height)
	var clearance := maxf(minimum_lane_gap, _player_speed * 0.5)
	var blocked: Array[int] = [overtaker.lane]
	for vehicle in vehicles:
		if vehicle == overtaker or absf(vehicle.y - player_y) >= clearance + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
			continue
		if not blocked.has(vehicle.lane):
			blocked.append(vehicle.lane)
		if vehicle.kind == Kind.SIGNAL_CHANGE and vehicle.warning_started and not blocked.has(vehicle.target_lane):
			blocked.append(vehicle.target_lane)
	for lane in range(lane_count):
		if abs(lane - _player_lane) <= 1 and not blocked.has(lane):
			return true
	return false

func _top_lane_has_minimum_gap(lane: int) -> bool:
	var lane_vehicles: Array[TrafficVehicle] = []
	for vehicle in vehicles:
		if vehicle.kind != Kind.FAST_OVERTAKE and vehicle.lane == lane:
			lane_vehicles.append(vehicle)
	for first_index in lane_vehicles.size():
		for second_index in range(first_index + 1, lane_vehicles.size()):
			if not vehicles_have_minimum_gap(lane_vehicles[first_index], lane_vehicles[second_index]):
				return false
	return true

func _spawn_next(player_speed: float, player_lane: int) -> void:
	if vehicles.size() >= max_active_vehicles:
		return
	var kind := _kind_for_next_spawn()
	var lane := _random.randi_range(0, lane_count - 1)
	var y := TrackGeometry.fast_overtake_spawn_y(_viewport_height) if kind == Kind.FAST_OVERTAKE else -minimum_spawn_distance
	if not _can_spawn_vehicle(kind, lane, y, player_speed, player_lane):
		return
	var vehicle := acquire_vehicle(kind, lane, y)
	vehicle.spawn_was_fair = true
	vehicles.append(vehicle)
	_spawn_history.append("%d:%d" % [kind, lane])

func _can_spawn_vehicle(kind: int, lane: int, y: float, player_speed: float, player_lane: int) -> bool:
	if not is_lane_valid(lane):
		return false
	var candidate := TrafficVehicle.new(kind, lane, TrackGeometry.fast_overtake_staging_y(_viewport_height) if kind == Kind.FAST_OVERTAKE else y)
	for vehicle in vehicles:
		if vehicle.lane == lane and not vehicles_have_minimum_gap(vehicle, candidate):
			return false
		if kind != Kind.FAST_OVERTAKE and vehicle.kind != Kind.FAST_OVERTAKE and abs(vehicle.lane - lane) <= 1 and not vehicles_have_minimum_gap(vehicle, candidate):
			return false
	return _has_escape_lane(candidate, player_lane, player_speed)

func _has_escape_lane(candidate: TrafficVehicle, player_lane: int, player_speed: float) -> bool:
	var dynamic_reaction_distance := maxf(minimum_lane_gap, player_speed)
	for candidate_lane in [player_lane - 1, player_lane + 1]:
		if not is_lane_valid(candidate_lane):
			continue
		var clear := true
		for vehicle in vehicles:
			if vehicle.lane == candidate_lane and absf(vehicle.y - candidate.y) < dynamic_reaction_distance + vehicle.half_length + candidate.half_length:
				clear = false
				break
		if clear:
			return true
	return false

func _target_lane_for(kind: int, lane: int) -> int:
	if kind != Kind.SIGNAL_CHANGE:
		return lane
	if lane == 0:
		return 1
	if lane == lane_count - 1:
		return lane_count - 2
	return lane + (-1 if _random.randi_range(0, 1) == 0 else 1)

func maximum_kind_for_stage() -> int:
	if difficulty_stage <= 0:
		return Kind.STEADY_SLOW
	if difficulty_stage == 1:
		return Kind.SIGNAL_CHANGE
	return Kind.TRUCK if difficulty_stage == 3 else Kind.FAST_OVERTAKE

func lane_change_warning_duration() -> float:
	return [0.90, 0.80, 0.70, 0.60][difficulty_stage]

func _kind_for_next_spawn() -> int:
	var schedule := _kind_schedule()
	var kind := schedule[_schedule_cursor % schedule.size()]
	_schedule_cursor += 1
	return kind

func _kind_schedule() -> Array[int]:
	match difficulty_stage:
		0:
			return [Kind.STEADY_SLOW]
		1:
			return [Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE]
		2:
			return [Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE]
		_:
			return [Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.TRUCK, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE]

func _spawn_interval_for_stage() -> float:
	return [0.85, 0.72, 0.62, 0.48][difficulty_stage]

func _speed_multiplier_for_stage() -> float:
	return [1.0, 1.0, 1.12, 1.22][difficulty_stage]

func is_fast_spawn_fair(player_speed: float, player_lane: int) -> bool:
	return _can_spawn_vehicle(Kind.FAST_OVERTAKE, player_lane, TrackGeometry.fast_overtake_spawn_y(_viewport_height), player_speed, player_lane)

func spawn_sequence() -> String:
	return "|".join(_spawn_history)

static func fast_warning_y(vehicle_y: float) -> float:
	return vehicle_y - 52.0

func _recycle_offscreen_vehicles() -> void:
	var active: Array[TrafficVehicle] = []
	for vehicle in vehicles:
		var is_offscreen := vehicle.y > TrackGeometry.normal_recycle_y(_viewport_height) if vehicle.kind != Kind.FAST_OVERTAKE else vehicle.y < TrackGeometry.FAST_RECYCLE_Y
		if is_offscreen:
			_pool.append(vehicle)
		else:
			active.append(vehicle)
	vehicles = active

func _constrain_top_vehicle_y(vehicle: TrafficVehicle, proposed_y: float) -> float:
	for other in vehicles:
		if other == vehicle or other.kind == Kind.FAST_OVERTAKE:
			continue
		var shares_reserved_space: bool = other.lane == vehicle.lane or ((vehicle.kind == Kind.TRUCK or other.kind == Kind.TRUCK) and abs(other.lane - vehicle.lane) <= 1)
		if not shares_reserved_space:
			continue
		var required_gap := minimum_lane_gap + vehicle.half_length + other.half_length
		if vehicle.y <= other.y and proposed_y > other.y - required_gap:
			return other.y - required_gap
	return proposed_y

func vehicles_have_minimum_gap(first: TrafficVehicle, second: TrafficVehicle, center_distance: float = -1.0) -> bool:
	var separation := absf(first.y - second.y) if center_distance < 0.0 else center_distance
	return separation >= minimum_lane_gap + first.half_length + second.half_length

func collision_distance_for(vehicle: TrafficVehicle) -> float:
	return GameConfig.COLLISION_LONGITUDINAL_DISTANCE + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH

func collision_lateral_distance_for(vehicle: TrafficVehicle) -> float:
	return GameConfig.COLLISION_LATERAL_DISTANCE + vehicle.half_width - TrafficVehicle.NORMAL_HALF_WIDTH
