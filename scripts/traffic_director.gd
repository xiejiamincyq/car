class_name TrafficDirector
extends RefCounted

const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const LaneEventDirector = preload("res://scripts/lane_event_director.gd")

enum Kind { STEADY_SLOW, SIGNAL_CHANGE, FAST_OVERTAKE, TRUCK }

const FAST_ROUTE_LOOKAHEAD := 620.0
const FAST_ROUTE_WARNING_SECONDS := 0.60
const FAST_LANE_CHANGE_SPEED := 3.4
const LANE_CHANGE_WARNING_ENTRY_Y := 80.0

var lane_count: int = 3
var minimum_spawn_distance: float = 620.0
var minimum_lane_gap: float = 180.0
var reaction_distance: float = 260.0
var max_active_vehicles: int = 8
var target_active_vehicles: int = 6
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
var lane_events: LaneEventDirector
var spawn_interval_multiplier := 1.0
var _visual_variant_cursor := 0
var track_pattern: StringName = &"coast_flow"
var track_spawn_interval_multiplier := 1.0
var track_event_interval_multiplier := 1.0
var difficulty_event_interval_multiplier := 1.0
var _spawn_exclusion_zones: Array[Vector2] = []
var random_lane_change_probability := 0.0
var random_lane_change_planned_count := 0

func _init(seed: int, lanes: int = 3, safe_distance: float = 620.0, lane_gap: float = 180.0) -> void:
	lane_count = lanes
	minimum_spawn_distance = safe_distance
	minimum_lane_gap = lane_gap
	_initial_seed = seed
	_random.seed = _initial_seed
	_spawn_history.clear()
	lane_events = LaneEventDirector.new(_event_seed(_initial_seed), lane_count, GameConfig.LANE_EVENTS_ENABLED)

func tick(delta: float, player_speed: float, player_lane: int = 1) -> void:
	_player_speed = player_speed
	_player_lane = player_lane
	if lane_events.state == LaneEventDirector.State.WARNING and not _closure_can_continue():
		lane_events.cancel_warning()
	lane_events.tick(delta, difficulty_stage, player_lane)
	if lane_events.state == LaneEventDirector.State.WARNING and not _closure_can_continue():
		lane_events.cancel_warning()
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_next(player_speed, player_lane)
		_spawn_cooldown = _spawn_interval_for_stage()
	for vehicle in vehicles:
		update_vehicle(vehicle, delta, player_speed)
	_recycle_offscreen_vehicles()

func acquire_vehicle(kind: int, lane: int, y: float) -> TrafficVehicle:
	var target_lane := _target_lane_for(kind, lane)
	var visual_variant := _visual_variant_cursor % 2 if kind == Kind.STEADY_SLOW else 0
	if kind == Kind.STEADY_SLOW:
		_visual_variant_cursor += 1
	var vehicle: TrafficVehicle
	if _pool.is_empty():
		vehicle = TrafficVehicle.new(kind, lane, y, target_lane, visual_variant)
		allocated_vehicle_count += 1
	else:
		vehicle = _pool.pop_back()
		vehicle.configure(kind, lane, y, target_lane, visual_variant)
	return vehicle

func reset(run_seed: int = -1) -> void:
	for vehicle in vehicles:
		_pool.append(vehicle)
	vehicles.clear()
	_next_kind = 0
	_schedule_cursor = 0
	_visual_variant_cursor = 0
	_spawn_cooldown = 0.7
	_spawn_exclusion_zones.clear()
	if run_seed >= 0:
		_initial_seed = run_seed
	_random.seed = _initial_seed
	_spawn_history.clear()
	lane_events.reset(_event_seed(_initial_seed))
	difficulty_stage = 0
	lane_change_started_count = 0
	random_lane_change_planned_count = 0

func set_difficulty_stage(stage: int) -> void:
	difficulty_stage = clampi(stage, 0, 3)

func set_viewport_height(viewport_height: float) -> void:
	_viewport_height = maxf(1.0, viewport_height)

func set_spawn_exclusion_zones(zones: Array[Vector2]) -> void:
	_spawn_exclusion_zones.assign(zones)

func configure_difficulty(profile: Dictionary) -> void:
	spawn_interval_multiplier = maxf(0.1, float(profile.traffic_interval_multiplier))
	difficulty_event_interval_multiplier = maxf(0.1, float(profile.event_interval_multiplier))
	random_lane_change_probability = clampf(float(profile.get("random_lane_change_probability", 0.0)), 0.0, 1.0)
	_apply_event_interval()

func configure_track(profile: Dictionary) -> void:
	track_pattern = StringName(profile.get("traffic_pattern", &"coast_flow"))
	track_event_interval_multiplier = maxf(0.1, float(profile.get("lane_event_interval_multiplier", 1.0)))
	track_spawn_interval_multiplier = maxf(0.1, float(profile.get("traffic_interval_multiplier", 1.0)))
	_apply_event_interval()

func update_vehicle(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	if vehicle.kind == Kind.FAST_OVERTAKE:
		_update_fast_overtaker(vehicle, delta, player_speed)
		return
	var relative_speed := player_speed - vehicle.cruise_speed
	if vehicle.lane_change_enabled:
		if lane_events.blocked_lane() >= 0 and vehicle.target_lane == lane_events.blocked_lane() and not vehicle.change_started:
			vehicle.target_lane = vehicle.lane
			vehicle.warning_started = false
			vehicle.warning_remaining = 0.0
		else:
			var lane_change_is_visible := _is_lane_change_visible(vehicle)
			if not vehicle.warning_started and lane_change_is_visible:
				vehicle.warning_started = true
				vehicle.warning_remaining = lane_change_warning_duration()
			elif vehicle.warning_remaining > 0.0:
				vehicle.warning_remaining = maxf(0.0, vehicle.warning_remaining - delta)
			if vehicle.warning_started and lane_change_is_visible and is_zero_approx(vehicle.warning_remaining) and not vehicle.change_started:
				if is_lane_change_safe(vehicle):
					vehicle.change_started = true
					lane_change_started_count += 1
				else:
					vehicle.warning_remaining = 0.35
		if vehicle.change_started:
			vehicle.lane_position = move_toward(vehicle.lane_position, float(vehicle.target_lane), 2.4 * delta)
			if is_equal_approx(vehicle.lane_position, float(vehicle.target_lane)):
				vehicle.lane = vehicle.target_lane
	var proposed_y := vehicle.y + relative_speed * _speed_multiplier_for_stage() * delta
	if relative_speed >= 0.0:
		proposed_y = _constrain_top_vehicle_y(vehicle, proposed_y)
		proposed_y = _constrain_player_escape_y(vehicle, proposed_y)
		proposed_y = _constrain_event_escape_y(vehicle, proposed_y)
	vehicle.y = proposed_y

func _update_fast_overtaker(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	var overtake_speed: float = (player_speed * 0.30 + 260.0) * _speed_multiplier_for_stage()
	var staging_y: float = TrackGeometry.fast_overtake_staging_y(_viewport_height)
	if vehicle.y > staging_y:
		vehicle.y = maxf(staging_y, vehicle.y - overtake_speed * delta)
		if vehicle.y <= staging_y:
			vehicle.overtake_warning_remaining = 1.0
		return
	if vehicle.overtake_warning_remaining > 0.0:
		if not vehicle.lane_change_enabled:
			_try_plan_fast_lane_change(vehicle)
		if vehicle.lane_change_enabled:
			_advance_fast_lane_change(vehicle, delta)
		vehicle.overtake_warning_remaining = maxf(0.0, vehicle.overtake_warning_remaining - delta)
		if is_zero_approx(vehicle.overtake_warning_remaining) and not _can_release_fast_overtaker(vehicle):
			vehicle.overtake_warning_remaining = 0.25
		return
	if vehicle.lane_change_enabled:
		_advance_fast_lane_change(vehicle, delta)
		if vehicle.lane_change_enabled:
			vehicle.y = _constrain_fast_overtaker_y(vehicle, vehicle.y)
			return
	if _try_plan_fast_lane_change(vehicle):
		return
	var proposed_y: float = vehicle.y - overtake_speed * delta
	vehicle.y = _constrain_fast_overtaker_y(vehicle, proposed_y)

func _try_plan_fast_lane_change(overtaker: TrafficVehicle) -> bool:
	if _nearest_fast_route_blocker(overtaker, FAST_ROUTE_LOOKAHEAD) == null:
		return false
	var route_lane: int = _best_fast_route_lane(overtaker)
	if route_lane < 0:
		return false
	_begin_fast_lane_change(overtaker, route_lane)
	return true

func _nearest_fast_route_blocker(overtaker: TrafficVehicle, lookahead: float) -> TrafficVehicle:
	var nearest: TrafficVehicle = null
	var nearest_distance: float = INF
	for other in vehicles:
		if other == overtaker or other.kind == Kind.FAST_OVERTAKE or other.lane != overtaker.lane:
			continue
		var forward_distance: float = overtaker.y - other.y
		if forward_distance <= 0.0 or forward_distance > lookahead:
			continue
		if forward_distance < nearest_distance:
			nearest = other
			nearest_distance = forward_distance
	return nearest

func _best_fast_route_lane(overtaker: TrafficVehicle) -> int:
	var best_lane: int = -1
	var best_clearance: float = -1.0
	for candidate_lane_value in [overtaker.lane - 1, overtaker.lane + 1]:
		var candidate_lane: int = candidate_lane_value
		if not is_lane_valid(candidate_lane) or candidate_lane == lane_events.blocked_lane():
			continue
		if not _fast_merge_lane_is_clear(overtaker, candidate_lane):
			continue
		if not _fast_route_preserves_player_options(overtaker, candidate_lane):
			continue
		var clearance: float = _fast_forward_clearance(overtaker, candidate_lane)
		var avoids_player: bool = candidate_lane != _player_lane
		var best_avoids_player: bool = best_lane >= 0 and best_lane != _player_lane
		if clearance > best_clearance or (is_equal_approx(clearance, best_clearance) and avoids_player and not best_avoids_player):
			best_lane = candidate_lane
			best_clearance = clearance
	return best_lane

func _fast_merge_lane_is_clear(overtaker: TrafficVehicle, candidate_lane: int) -> bool:
	for other in vehicles:
		if other == overtaker:
			continue
		var reserves_lane: bool = other.lane_change_enabled and other.warning_started and other.target_lane == candidate_lane
		if other.lane != candidate_lane and not reserves_lane:
			continue
		var required_gap: float = minimum_lane_gap + overtaker.half_length + other.half_length
		if absf(overtaker.y - other.y) < required_gap:
			return false
	return true

func _fast_forward_clearance(overtaker: TrafficVehicle, candidate_lane: int) -> float:
	var clearance: float = FAST_ROUTE_LOOKAHEAD * 2.0
	for other in vehicles:
		if other == overtaker or other.kind == Kind.FAST_OVERTAKE or other.lane != candidate_lane:
			continue
		var forward_distance: float = overtaker.y - other.y
		if forward_distance > 0.0:
			clearance = minf(clearance, forward_distance)
	return clearance

func _begin_fast_lane_change(overtaker: TrafficVehicle, target_lane: int) -> void:
	overtaker.target_lane = target_lane
	overtaker.lane_change_enabled = true
	overtaker.warning_started = true
	overtaker.warning_remaining = FAST_ROUTE_WARNING_SECONDS
	overtaker.change_started = false

func _advance_fast_lane_change(overtaker: TrafficVehicle, delta: float) -> void:
	if overtaker.target_lane == lane_events.blocked_lane() and not overtaker.change_started:
		_cancel_fast_lane_change(overtaker)
		return
	if not _fast_route_preserves_player_options(overtaker, overtaker.target_lane):
		var crossed_lane_center: bool = absf(overtaker.lane_position - float(overtaker.lane)) >= 0.5
		if overtaker.change_started and crossed_lane_center:
			_complete_fast_lane_change(overtaker)
		else:
			_cancel_fast_lane_change(overtaker)
		return
	if overtaker.warning_remaining > 0.0:
		overtaker.warning_remaining = maxf(0.0, overtaker.warning_remaining - delta)
		return
	if not overtaker.change_started:
		if not is_lane_change_safe(overtaker):
			overtaker.warning_remaining = 0.20
			return
		overtaker.change_started = true
		lane_change_started_count += 1
	overtaker.lane_position = move_toward(overtaker.lane_position, float(overtaker.target_lane), FAST_LANE_CHANGE_SPEED * delta)
	if is_equal_approx(overtaker.lane_position, float(overtaker.target_lane)):
		_complete_fast_lane_change(overtaker)

func _complete_fast_lane_change(overtaker: TrafficVehicle) -> void:
	overtaker.lane = overtaker.target_lane
	overtaker.lane_position = float(overtaker.lane)
	overtaker.lane_change_enabled = false
	overtaker.warning_started = false
	overtaker.warning_remaining = 0.0
	overtaker.change_started = false

func _cancel_fast_lane_change(overtaker: TrafficVehicle) -> void:
	overtaker.target_lane = overtaker.lane
	overtaker.lane_position = float(overtaker.lane)
	overtaker.lane_change_enabled = false
	overtaker.warning_started = false
	overtaker.warning_remaining = 0.0
	overtaker.change_started = false

func _constrain_fast_overtaker_y(overtaker: TrafficVehicle, proposed_y: float) -> float:
	var constrained_y: float = proposed_y
	for other in vehicles:
		if other == overtaker or other.kind == Kind.FAST_OVERTAKE or other.lane != overtaker.lane or other.y >= overtaker.y:
			continue
		var required_gap: float = minimum_lane_gap + overtaker.half_length + other.half_length
		constrained_y = maxf(constrained_y, other.y + required_gap)
	return minf(overtaker.y, constrained_y)

func is_lane_valid(lane: int) -> bool:
	return lane >= 0 and lane < lane_count

func _is_lane_change_visible(vehicle: TrafficVehicle) -> bool:
	return vehicle.y >= LANE_CHANGE_WARNING_ENTRY_Y and vehicle.y <= _viewport_height - vehicle.half_length

func is_lane_change_safe(vehicle: TrafficVehicle) -> bool:
	if not is_lane_valid(vehicle.target_lane):
		return false
	for other in vehicles:
		if other == vehicle:
			continue
		var reserves_target := other.lane_change_enabled and other.warning_started and other.target_lane == vehicle.target_lane
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
	if lane_events.blocked_lane() >= 0:
		blocked.append(lane_events.blocked_lane())
	for vehicle in vehicles:
		if absf(vehicle.y - y) >= clearance + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
			continue
		if not blocked.has(vehicle.lane):
			blocked.append(vehicle.lane)
		if vehicle.lane_change_enabled and vehicle.warning_started and not blocked.has(vehicle.target_lane):
			blocked.append(vehicle.target_lane)
	blocked.sort()
	return blocked

func reachable_player_lanes(player_lane: int, player_y: float, clearance: float) -> Array[int]:
	var blocked: Array[int] = []
	if lane_events.blocked_lane() >= 0:
		blocked.append(lane_events.blocked_lane())
	for vehicle in vehicles:
		if absf(vehicle.y - player_y) >= clearance + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
			continue
		if vehicle.kind == Kind.FAST_OVERTAKE and vehicle.overtake_warning_remaining > 0.0:
			continue
		if not blocked.has(vehicle.lane):
			blocked.append(vehicle.lane)
		if vehicle.lane_change_enabled and vehicle.warning_started and not blocked.has(vehicle.target_lane):
			blocked.append(vehicle.target_lane)
	var reachable: Array[int] = []
	for lane in range(lane_count):
		if abs(lane - player_lane) <= 1 and not blocked.has(lane):
			reachable.append(lane)
	return reachable

func _can_release_fast_overtaker(overtaker: TrafficVehicle) -> bool:
	var planned_lane: int = overtaker.target_lane if overtaker.lane_change_enabled else -1
	return _player_has_escape_around_fast(overtaker, planned_lane)

func _fast_route_preserves_player_options(overtaker: TrafficVehicle, planned_lane: int) -> bool:
	var options_before: int = _player_escape_count_around_fast(overtaker, -1)
	var options_after: int = _player_escape_count_around_fast(overtaker, planned_lane)
	return options_after > 0 or options_after >= options_before

func _player_has_escape_around_fast(overtaker: TrafficVehicle, planned_lane: int = -1) -> bool:
	return _player_escape_count_around_fast(overtaker, planned_lane) > 0

func _player_escape_count_around_fast(overtaker: TrafficVehicle, planned_lane: int = -1) -> int:
	var player_y := TrackGeometry.player_y(_viewport_height)
	var clearance := maxf(minimum_lane_gap, _player_speed * 0.5)
	var blocked: Array[int] = []
	if absf(overtaker.y - player_y) < clearance + overtaker.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
		blocked.append(overtaker.lane)
		if is_lane_valid(planned_lane) and not blocked.has(planned_lane):
			blocked.append(planned_lane)
	if lane_events.blocked_lane() >= 0 and not blocked.has(lane_events.blocked_lane()):
		blocked.append(lane_events.blocked_lane())
	for vehicle in vehicles:
		if vehicle == overtaker or absf(vehicle.y - player_y) >= clearance + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
			continue
		if vehicle.kind == Kind.FAST_OVERTAKE and vehicle.overtake_warning_remaining > 0.0:
			continue
		if not blocked.has(vehicle.lane):
			blocked.append(vehicle.lane)
		if vehicle.lane_change_enabled and vehicle.warning_started and not blocked.has(vehicle.target_lane):
			blocked.append(vehicle.target_lane)
	var available_lanes := 0
	for lane in range(lane_count):
		if abs(lane - _player_lane) <= 1 and not blocked.has(lane):
			available_lanes += 1
	return available_lanes

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
	if vehicles.size() >= target_active_vehicles:
		return
	var kind := _kind_for_next_spawn()
	var lane := _random.randi_range(0, lane_count - 1)
	var y := TrackGeometry.fast_overtake_spawn_y(_viewport_height) if kind == Kind.FAST_OVERTAKE else -minimum_spawn_distance
	var candidate := acquire_vehicle(kind, lane, y)
	_plan_random_lane_change(candidate)
	if not _can_spawn_candidate(candidate, player_speed, player_lane):
		_pool.append(candidate)
		return
	candidate.spawn_was_fair = true
	vehicles.append(candidate)
	if candidate.kind == Kind.STEADY_SLOW and candidate.lane_change_enabled:
		random_lane_change_planned_count += 1
	_spawn_history.append("%d:%d" % [kind, lane])

func _can_spawn_vehicle(kind: int, lane: int, y: float, player_speed: float, player_lane: int) -> bool:
	if not is_lane_valid(lane):
		return false
	var candidate := TrafficVehicle.new(kind, lane, y, lane)
	return _can_spawn_candidate(candidate, player_speed, player_lane)

func _can_spawn_candidate(candidate: TrafficVehicle, player_speed: float, player_lane: int) -> bool:
	if candidate.lane == lane_events.blocked_lane():
		return false
	if candidate.lane_change_enabled and candidate.target_lane == lane_events.blocked_lane():
		return false
	if _overlaps_spawn_exclusion(candidate):
		return false
	for vehicle in vehicles:
		if vehicle.lane == candidate.lane and not vehicles_have_minimum_gap(vehicle, candidate):
			return false
		if candidate.kind != Kind.FAST_OVERTAKE and vehicle.kind != Kind.FAST_OVERTAKE and abs(vehicle.lane - candidate.lane) <= 1 and not vehicles_have_minimum_gap(vehicle, candidate):
			return false
	return _has_escape_lane(candidate, player_lane, player_speed)

func _overlaps_spawn_exclusion(candidate: TrafficVehicle) -> bool:
	var clearance := GameConfig.FUEL_SPAWN_SAFETY_DISTANCE + candidate.half_length - TrafficVehicle.NORMAL_HALF_LENGTH
	for zone in _spawn_exclusion_zones:
		if int(zone.x) == candidate.lane and absf(zone.y - candidate.y) < clearance:
			return true
	return false

func _has_escape_lane(candidate: TrafficVehicle, player_lane: int, player_speed: float) -> bool:
	var dynamic_reaction_distance := maxf(minimum_lane_gap, player_speed)
	for candidate_lane in [player_lane - 1, player_lane + 1]:
		if not is_lane_valid(candidate_lane):
			continue
		if candidate_lane == lane_events.blocked_lane():
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
	return _random_adjacent_lane(lane)

func _plan_random_lane_change(vehicle: TrafficVehicle) -> void:
	if vehicle.kind != Kind.STEADY_SLOW or random_lane_change_probability <= 0.0 or _random.randf() >= random_lane_change_probability:
		return
	vehicle.target_lane = _random_adjacent_lane(vehicle.lane)
	vehicle.lane_change_enabled = vehicle.target_lane != vehicle.lane

func _random_adjacent_lane(lane: int) -> int:
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
			match track_pattern:
				&"harbor_heavy": return [Kind.STEADY_SLOW, Kind.TRUCK, Kind.SIGNAL_CHANGE, Kind.STEADY_SLOW]
				&"ridge_weave": return [Kind.SIGNAL_CHANGE, Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE]
				&"express_fast": return [Kind.STEADY_SLOW, Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE]
				_: return [Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE]
		_:
			match track_pattern:
				&"harbor_heavy": return [Kind.TRUCK, Kind.SIGNAL_CHANGE, Kind.STEADY_SLOW, Kind.TRUCK, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE]
				&"ridge_weave": return [Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE, Kind.TRUCK]
				&"express_fast": return [Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE]
				_: return [Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.TRUCK, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.STEADY_SLOW]

func _apply_event_interval() -> void:
	lane_events.configure_interval_multiplier(track_event_interval_multiplier * difficulty_event_interval_multiplier)

func _spawn_interval_for_stage() -> float:
	return [0.85, 0.72, 0.62, 0.48][difficulty_stage] * effective_spawn_interval_multiplier()

func effective_spawn_interval_multiplier() -> float:
	return track_spawn_interval_multiplier * spawn_interval_multiplier

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
		var is_offscreen := vehicle.y > TrackGeometry.normal_recycle_y(_viewport_height) or vehicle.y < -minimum_spawn_distance * 2.0 if vehicle.kind != Kind.FAST_OVERTAKE else vehicle.y < TrackGeometry.FAST_RECYCLE_Y
		if is_offscreen:
			_pool.append(vehicle)
		else:
			active.append(vehicle)
	vehicles = active

func _constrain_top_vehicle_y(vehicle: TrafficVehicle, proposed_y: float) -> float:
	var forward_limit := proposed_y
	for other in vehicles:
		if other == vehicle or other.kind == Kind.FAST_OVERTAKE:
			continue
		var shares_reserved_space: bool = other.lane == vehicle.lane or ((vehicle.kind == Kind.TRUCK or other.kind == Kind.TRUCK) and abs(other.lane - vehicle.lane) <= 1)
		if not shares_reserved_space:
			continue
		var required_gap := minimum_lane_gap + vehicle.half_length + other.half_length
		if vehicle.y <= other.y and proposed_y > other.y - required_gap:
			forward_limit = minf(forward_limit, other.y - required_gap)
	return forward_limit

func _constrain_player_escape_y(vehicle: TrafficVehicle, proposed_y: float) -> float:
	var player_y := TrackGeometry.player_y(_viewport_height)
	if vehicle.y >= player_y:
		return proposed_y
	var clearance := GameConfig.COLLISION_LONGITUDINAL_DISTANCE + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH
	var forward_limit := player_y - clearance
	if proposed_y < forward_limit or _player_keeps_escape_with_vehicle(vehicle, player_y, clearance):
		return proposed_y
	return minf(proposed_y, forward_limit)

func _player_keeps_escape_with_vehicle(candidate: TrafficVehicle, player_y: float, clearance: float) -> bool:
	var blocked: Array[int] = []
	if lane_events.blocked_lane() >= 0:
		blocked.append(lane_events.blocked_lane())
	for other in vehicles:
		if other == candidate:
			continue
		var other_clearance := clearance + other.half_length - TrafficVehicle.NORMAL_HALF_LENGTH
		if absf(other.y - player_y) >= other_clearance:
			continue
		if other.kind == Kind.FAST_OVERTAKE and other.overtake_warning_remaining > 0.0:
			continue
		if not blocked.has(other.lane):
			blocked.append(other.lane)
		if other.lane_change_enabled and other.warning_started and not blocked.has(other.target_lane):
			blocked.append(other.target_lane)
	if not blocked.has(candidate.lane):
		blocked.append(candidate.lane)
	if candidate.lane_change_enabled and candidate.warning_started and not blocked.has(candidate.target_lane):
		blocked.append(candidate.target_lane)
	for lane in range(lane_count):
		if abs(lane - _player_lane) <= 1 and not blocked.has(lane):
			return true
	return false

func vehicles_have_minimum_gap(first: TrafficVehicle, second: TrafficVehicle, center_distance: float = -1.0) -> bool:
	var separation := absf(first.y - second.y) if center_distance < 0.0 else center_distance
	return separation >= minimum_lane_gap + first.half_length + second.half_length

func collision_distance_for(vehicle: TrafficVehicle) -> float:
	return GameConfig.COLLISION_LONGITUDINAL_DISTANCE + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH

func collision_lateral_distance_for(vehicle: TrafficVehicle) -> float:
	return GameConfig.COLLISION_LATERAL_DISTANCE + vehicle.half_width - TrafficVehicle.NORMAL_HALF_WIDTH

func _closure_can_continue() -> bool:
	var player_y := TrackGeometry.player_y(_viewport_height)
	if reachable_player_lanes(_player_lane, player_y, GameConfig.COLLISION_LONGITUDINAL_DISTANCE).is_empty():
		return false
	var reserved_lane := lane_events.blocked_lane()
	for vehicle in vehicles:
		if vehicle.change_started and vehicle.target_lane == reserved_lane:
			return false
	return true

func _constrain_event_escape_y(vehicle: TrafficVehicle, proposed_y: float) -> float:
	if lane_events.blocked_lane() < 0 or vehicle.lane != _player_lane or vehicle.y >= TrackGeometry.player_y(_viewport_height):
		return proposed_y
	var player_y := TrackGeometry.player_y(_viewport_height)
	var clearance := GameConfig.COLLISION_LONGITUDINAL_DISTANCE + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH
	var forward_limit := player_y - clearance
	for other in vehicles:
		if other == vehicle or other.kind == Kind.FAST_OVERTAKE or other.lane != vehicle.lane:
			continue
		if other.y > vehicle.y and other.y < player_y:
			var required_gap := minimum_lane_gap + vehicle.half_length + other.half_length
			forward_limit = minf(forward_limit, other.y - required_gap)
	return minf(proposed_y, forward_limit)

static func _event_seed(run_seed: int) -> int:
	return run_seed ^ 0x4C414E45
