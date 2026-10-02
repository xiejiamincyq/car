class_name FuelSpawnDirector
extends RefCounted

const FuelPickup = preload("res://scripts/fuel_pickup.gd")
const DifficultyProfile = preload("res://scripts/difficulty_profile.gd")
const RETRY_INTERVAL := 0.5
const PICKUP_SPAWN_Y := -90.0

var lane_count: int
var spawn_interval: float
var spawn_remaining: float
var active_limit: int
var minimum_road_advance: float
var pending := false
var has_spawned := false
var road_advance_since_spawn := 0.0
var opportunities := 0
var spawned := 0
var blocked_attempts := 0
var _random := RandomNumberGenerator.new()

func _init(run_seed: int, lanes: int, interval: float) -> void:
	lane_count = maxi(1, lanes)
	spawn_interval = maxf(RETRY_INTERVAL, interval)
	var defaults := DifficultyProfile.for_index(1)
	active_limit = defaults.supply_active_limit
	minimum_road_advance = defaults.supply_minimum_road_advance
	reset(run_seed)

func configure_schedule(interval: float, limit: int, road_advance: float) -> void:
	var next_interval := maxf(RETRY_INTERVAL, interval)
	var next_limit := maxi(1, limit)
	var next_advance := maxf(0.0, road_advance)
	if spawn_interval == next_interval and active_limit == next_limit and minimum_road_advance == next_advance:
		return
	spawn_interval = next_interval
	active_limit = next_limit
	minimum_road_advance = next_advance
	_reset_future_schedule()

func reset(run_seed: int) -> void:
	_random.seed = run_seed
	has_spawned = false
	opportunities = 0
	spawned = 0
	blocked_attempts = 0
	_reset_future_schedule()

func _reset_future_schedule() -> void:
	spawn_remaining = spawn_interval
	pending = false
	road_advance_since_spawn = 0.0

func tick(delta: float, blocked_lanes: Array, player_lane: int, active_count: int, forward_advance: float) -> FuelPickup:
	# No stationary clock debt or retry storm; both quantities are real forward
	# movement for this tick, not wrapped road_scroll or HUD distance units.
	if delta <= 0.0 or forward_advance <= 0.0:
		return null
	road_advance_since_spawn += forward_advance
	spawn_remaining = maxf(0.0, spawn_remaining - delta)
	if not is_zero_approx(spawn_remaining): return null
	if not pending:
		pending = true
		opportunities += 1
	if active_count >= active_limit or (has_spawned and road_advance_since_spawn < minimum_road_advance):
		_defer_attempt()
		return null
	var reachable_lanes: Array[int] = []
	for lane in range(lane_count):
		if abs(lane - player_lane) <= 1 and not blocked_lanes.has(lane):
			reachable_lanes.append(lane)
	if reachable_lanes.is_empty():
		_defer_attempt()
		return null
	var lane := reachable_lanes[_random.randi_range(0, reachable_lanes.size() - 1)]
	spawn_remaining = spawn_interval
	pending = false
	has_spawned = true
	road_advance_since_spawn = 0.0
	spawned += 1
	return FuelPickup.new(lane, PICKUP_SPAWN_Y)

func _defer_attempt() -> void:
	blocked_attempts += 1
	spawn_remaining = RETRY_INTERVAL
