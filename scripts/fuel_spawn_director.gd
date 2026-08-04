class_name FuelSpawnDirector
extends RefCounted

const FuelPickup = preload("res://scripts/fuel_pickup.gd")
const RETRY_INTERVAL := 0.5
const PICKUP_SPAWN_Y := -90.0

var lane_count: int
var spawn_interval: float
var spawn_remaining: float
var _random := RandomNumberGenerator.new()

func _init(run_seed: int, lanes: int, interval: float) -> void:
	lane_count = maxi(1, lanes)
	spawn_interval = maxf(RETRY_INTERVAL, interval)
	reset(run_seed)

func reset(run_seed: int) -> void:
	_random.seed = run_seed
	spawn_remaining = spawn_interval

func tick(delta: float, blocked_lanes: Array, player_lane: int) -> FuelPickup:
	spawn_remaining -= maxf(0.0, delta)
	if spawn_remaining > 0.0:
		return null
	var reachable_lanes: Array[int] = []
	for lane in range(lane_count):
		if abs(lane - player_lane) <= 1 and not blocked_lanes.has(lane):
			reachable_lanes.append(lane)
	if reachable_lanes.is_empty():
		spawn_remaining = RETRY_INTERVAL
		return null
	var lane := reachable_lanes[_random.randi_range(0, reachable_lanes.size() - 1)]
	spawn_remaining = spawn_interval
	return FuelPickup.new(lane, PICKUP_SPAWN_Y)
