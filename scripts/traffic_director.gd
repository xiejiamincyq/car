class_name TrafficDirector
extends RefCounted

const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")

enum Kind { STEADY_SLOW, SIGNAL_CHANGE, FAST_OVERTAKE }

var lane_count: int = 3
var minimum_spawn_distance: float = 620.0
var minimum_lane_gap: float = 180.0
var vehicles: Array[TrafficVehicle] = []
var _random := RandomNumberGenerator.new()
var _initial_seed: int
var _spawn_counter: int = 0
var _spawn_cooldown: float = 0.7

func _init(seed: int, lanes: int = 3, safe_distance: float = 620.0, lane_gap: float = 180.0) -> void:
	lane_count = lanes
	minimum_spawn_distance = safe_distance
	minimum_lane_gap = lane_gap
	_initial_seed = seed
	_random.seed = _initial_seed

func fill_to_count(count: int) -> void:
	while vehicles.size() < count:
		spawn_next()

func spawn_next() -> TrafficVehicle:
	var kind: int = _spawn_counter % Kind.size()
	var lane: int = _random.randi_range(0, lane_count - 1)
	var y := -minimum_spawn_distance - float(_spawn_counter) * minimum_lane_gap
	var vehicle := create_vehicle(kind, lane, y)
	vehicles.append(vehicle)
	_spawn_counter += 1
	return vehicle

func create_vehicle(kind: int, lane: int, y: float) -> TrafficVehicle:
	var target_lane := lane
	if kind == Kind.SIGNAL_CHANGE:
		target_lane = (lane + 1 + _random.randi_range(0, lane_count - 2)) % lane_count
	var vehicle := TrafficVehicle.new(kind, lane, y, target_lane)
	if kind == Kind.SIGNAL_CHANGE:
		vehicle.warning_remaining = 0.75
	return vehicle

func tick(delta: float, player_speed: float) -> void:
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		spawn_next()
		_spawn_cooldown = 0.85
	for vehicle in vehicles:
		update_vehicle(vehicle, delta, player_speed)
	vehicles = vehicles.filter(func(vehicle: TrafficVehicle) -> bool: return vehicle.y < 860.0)

func reset() -> void:
	vehicles.clear()
	_spawn_counter = 0
	_spawn_cooldown = 0.7
	_random.seed = _initial_seed

func update_vehicle(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	var relative_speed := player_speed * 0.45
	match vehicle.kind:
		Kind.STEADY_SLOW:
			relative_speed += 105.0
		Kind.SIGNAL_CHANGE:
			relative_speed += 165.0
			if vehicle.warning_remaining > 0.0:
				vehicle.warning_remaining = maxf(0.0, vehicle.warning_remaining - delta)
			if is_zero_approx(vehicle.warning_remaining) and not vehicle.change_started:
				vehicle.lane = vehicle.target_lane
				vehicle.change_started = true
		Kind.FAST_OVERTAKE:
			relative_speed += 280.0
	vehicle.y += relative_speed * delta

func is_lane_valid(lane: int) -> bool:
	return lane >= 0 and lane < lane_count

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

func spawn_signature() -> String:
	var entries: PackedStringArray = []
	for vehicle in vehicles:
		entries.append("%d:%d:%.0f" % [vehicle.kind, vehicle.lane, vehicle.y])
	return "|".join(entries)
