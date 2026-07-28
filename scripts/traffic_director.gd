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

func _init(seed: int, lanes: int = 3, safe_distance: float = 620.0, lane_gap: float = 180.0) -> void:
	lane_count = lanes
	minimum_spawn_distance = safe_distance
	minimum_lane_gap = lane_gap
	_initial_seed = seed
	_random.seed = _initial_seed

func tick(delta: float, player_speed: float) -> void:
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_next()
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

func update_vehicle(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	if vehicle.kind == Kind.FAST_OVERTAKE:
		vehicle.y -= (player_speed * 0.58 + 310.0) * delta
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
			if is_zero_approx(vehicle.warning_remaining) and is_lane_change_safe(vehicle):
				vehicle.lane = vehicle.target_lane
				vehicle.change_started = true
	vehicle.y = _constrain_top_vehicle_y(vehicle, vehicle.y + relative_speed * delta)

func is_lane_valid(lane: int) -> bool:
	return lane >= 0 and lane < lane_count

func is_lane_change_safe(vehicle: TrafficVehicle) -> bool:
	if not is_lane_valid(vehicle.target_lane):
		return false
	for other in vehicles:
		if other != vehicle and other.lane == vehicle.target_lane and absf(other.y - vehicle.y) < minimum_lane_gap:
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

func _spawn_next() -> void:
	if vehicles.size() >= max_active_vehicles:
		return
	var kind := _next_kind
	_next_kind = (_next_kind + 1) % Kind.size()
	var lane := _random.randi_range(0, lane_count - 1)
	var y := 1080.0 if kind == Kind.FAST_OVERTAKE else -minimum_spawn_distance
	if kind != Kind.FAST_OVERTAKE and not _can_spawn_top_vehicle(lane, y):
		return
	var vehicle := acquire_vehicle(kind, lane, y)
	vehicle.spawn_was_fair = true
	vehicles.append(vehicle)

func _can_spawn_top_vehicle(lane: int, y: float) -> bool:
	if not is_lane_valid(lane):
		return false
	for vehicle in vehicles:
		if vehicle.lane == lane and absf(vehicle.y - y) < minimum_lane_gap:
			return false
	var candidate := TrafficVehicle.new(Kind.STEADY_SLOW, lane, y)
	return _has_escape_lane(candidate)

func _has_escape_lane(candidate: TrafficVehicle) -> bool:
	for candidate_lane in lane_count:
		if candidate_lane == candidate.lane:
			continue
		var clear := true
		for vehicle in vehicles:
			if vehicle.lane == candidate_lane and absf(vehicle.y - candidate.y) < reaction_distance:
				clear = false
				break
		if clear:
			return true
	return false

func _target_lane_for(kind: int, lane: int) -> int:
	if kind != Kind.SIGNAL_CHANGE:
		return lane
	return (lane + 1 + _random.randi_range(0, lane_count - 2)) % lane_count

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
