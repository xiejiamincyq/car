class_name TrafficDirector
extends RefCounted

const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")

enum Kind { STEADY_SLOW, SIGNAL_CHANGE, FAST_OVERTAKE }

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
var _spawn_cooldown: float = 0.7
var _player_speed: float = 0.0
var _player_lane: int = 1
var _spawn_history: PackedStringArray = []

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
		_spawn_cooldown = 0.85
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

func reset() -> void:
	for vehicle in vehicles:
		_pool.append(vehicle)
	vehicles.clear()
	_next_kind = 0
	_spawn_cooldown = 0.7
	_random.seed = _initial_seed
	_spawn_history.clear()

func update_vehicle(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	if vehicle.kind == Kind.FAST_OVERTAKE:
		var overtake_speed := player_speed * 0.30 + 260.0
		if vehicle.y > 700.0:
			vehicle.y = maxf(700.0, vehicle.y - overtake_speed * delta)
			if vehicle.y <= 700.0:
				vehicle.overtake_warning_remaining = 1.0
		elif vehicle.overtake_warning_remaining > 0.0:
			vehicle.overtake_warning_remaining = maxf(0.0, vehicle.overtake_warning_remaining - delta)
		else:
			vehicle.y -= overtake_speed * delta
		return
	var relative_speed := player_speed * 0.45
	if vehicle.kind == Kind.STEADY_SLOW:
		relative_speed += 105.0
	else:
		relative_speed += 165.0
		if not vehicle.warning_started and vehicle.y >= 80.0:
			vehicle.warning_started = true
			vehicle.warning_remaining = 0.75
		elif vehicle.warning_remaining > 0.0:
			vehicle.warning_remaining = maxf(0.0, vehicle.warning_remaining - delta)
		if is_zero_approx(vehicle.warning_remaining) and not vehicle.change_started:
			if is_lane_change_safe(vehicle):
				vehicle.change_started = true
			else:
				vehicle.warning_remaining = 0.35
		if vehicle.change_started:
			vehicle.lane_position = move_toward(vehicle.lane_position, float(vehicle.target_lane), 2.4 * delta)
			if is_equal_approx(vehicle.lane_position, float(vehicle.target_lane)):
				vehicle.lane = vehicle.target_lane
	vehicle.y = _constrain_top_vehicle_y(vehicle, vehicle.y + relative_speed * delta)

func is_lane_valid(lane: int) -> bool:
	return lane >= 0 and lane < lane_count

func is_lane_change_safe(vehicle: TrafficVehicle) -> bool:
	if not is_lane_valid(vehicle.target_lane):
		return false
	for other in vehicles:
		if other == vehicle:
			continue
		var reserves_target := other.kind == Kind.SIGNAL_CHANGE and other.warning_started and other.target_lane == vehicle.target_lane
		if (other.lane == vehicle.target_lane or reserves_target) and absf(other.y - vehicle.y) < minimum_lane_gap:
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
			if absf(lane_vehicles[first_index].y - lane_vehicles[second_index].y) < minimum_lane_gap:
				return false
	return true

func _top_lane_has_minimum_gap(lane: int) -> bool:
	var lane_vehicles: Array[TrafficVehicle] = []
	for vehicle in vehicles:
		if vehicle.kind != Kind.FAST_OVERTAKE and vehicle.lane == lane:
			lane_vehicles.append(vehicle)
	for first_index in lane_vehicles.size():
		for second_index in range(first_index + 1, lane_vehicles.size()):
			if absf(lane_vehicles[first_index].y - lane_vehicles[second_index].y) < minimum_lane_gap:
				return false
	return true

func _spawn_next(player_speed: float, player_lane: int) -> void:
	if vehicles.size() >= max_active_vehicles:
		return
	var kind := _next_kind
	_next_kind = (_next_kind + 1) % Kind.size()
	var lane := _random.randi_range(0, lane_count - 1)
	var y := 1100.0 if kind == Kind.FAST_OVERTAKE else -minimum_spawn_distance
	if not _can_spawn_vehicle(kind, lane, y, player_speed, player_lane):
		return
	var vehicle := acquire_vehicle(kind, lane, y)
	vehicle.spawn_was_fair = true
	vehicles.append(vehicle)
	_spawn_history.append("%d:%d" % [kind, lane])

func _can_spawn_vehicle(kind: int, lane: int, y: float, player_speed: float, player_lane: int) -> bool:
	if not is_lane_valid(lane):
		return false
	for vehicle in vehicles:
		if vehicle.lane == lane and absf(vehicle.y - y) < minimum_lane_gap:
			return false
	var candidate := TrafficVehicle.new(kind, lane, 700.0 if kind == Kind.FAST_OVERTAKE else y)
	return _has_escape_lane(candidate, player_lane, player_speed)

func _has_escape_lane(candidate: TrafficVehicle, player_lane: int, player_speed: float) -> bool:
	var dynamic_reaction_distance := maxf(minimum_lane_gap, player_speed)
	for candidate_lane in [player_lane - 1, player_lane + 1]:
		if not is_lane_valid(candidate_lane):
			continue
		var clear := true
		for vehicle in vehicles:
			if vehicle.lane == candidate_lane and absf(vehicle.y - candidate.y) < dynamic_reaction_distance:
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

func is_fast_spawn_fair(player_speed: float, player_lane: int) -> bool:
	return _can_spawn_vehicle(Kind.FAST_OVERTAKE, player_lane, 1100.0, player_speed, player_lane)

func spawn_sequence() -> String:
	return "|".join(_spawn_history)

static func fast_warning_y(vehicle_y: float) -> float:
	return vehicle_y - 52.0

func _recycle_offscreen_vehicles() -> void:
	var active: Array[TrafficVehicle] = []
	for vehicle in vehicles:
		var is_offscreen := vehicle.y > 860.0 if vehicle.kind != Kind.FAST_OVERTAKE else vehicle.y < -100.0
		if is_offscreen:
			_pool.append(vehicle)
		else:
			active.append(vehicle)
	vehicles = active

func _constrain_top_vehicle_y(vehicle: TrafficVehicle, proposed_y: float) -> float:
	for other in vehicles:
		if other == vehicle or other.kind == Kind.FAST_OVERTAKE or other.lane != vehicle.lane:
			continue
		if vehicle.y <= other.y and proposed_y > other.y - minimum_lane_gap:
			return other.y - minimum_lane_gap
	return proposed_y
