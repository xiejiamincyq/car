class_name TrafficDirector
extends RefCounted

const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const LaneEventDirector = preload("res://scripts/lane_event_director.gd")
const TrafficSafetyPolicy = preload("res://scripts/traffic_safety_policy.gd")
const FastPriorityTraffic = preload("res://scripts/fast_priority_traffic.gd")

enum Kind { STEADY_SLOW, SIGNAL_CHANGE, FAST_OVERTAKE, TRUCK }

const FAST_ROUTE_LOOKAHEAD := 620.0
const FAST_ROUTE_WARNING_SECONDS := 0.60
const FAST_LANE_CHANGE_SPEED := 3.4
const NORMAL_LANE_CHANGE_SPEED := 2.4
const LANE_CHANGE_WARNING_ENTRY_Y := 40.0
const BRAKING_REACTION_SECONDS := 0.25
const NORMAL_SPEED_MIN := 180.0
const NORMAL_SPEED_MAX := 220.0
const NORMAL_SPEED_STEP := 20
const NPC_ACCELERATION := 140.0
const NPC_BRAKING := 420.0
const FOLLOWING_BODY_MARGIN := 24.0
const LANE_CHANGE_WAIT_LIMIT := 2.0
const LANE_CHANGE_COOLDOWN := 0.75

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
var lane_warning_multiplier := 1.0
var early_fast_overtakers := false
var random_lane_change_planned_count := 0
var _core_snapshot_y := 0.0
var _closure_birth_step_seconds := 0.0
var fast_priority := FastPriorityTraffic.new()

func _init(seed: int, lanes: int = 3, safe_distance: float = 620.0, lane_gap: float = 180.0) -> void:
	lane_count = lanes
	minimum_spawn_distance = safe_distance
	minimum_lane_gap = lane_gap
	_initial_seed = seed
	_random.seed = _initial_seed
	_spawn_history.clear()
	lane_events = LaneEventDirector.new(_event_seed(_initial_seed), lane_count, GameConfig.LANE_EVENTS_ENABLED)

func tick(delta: float, player_speed: float, player_lane: int = 1) -> void:
	var frame_start: Dictionary = {}
	for vehicle in vehicles:
		frame_start[vehicle.get_instance_id()] = {"generation":vehicle.motion_generation,"position":Vector2(vehicle.lane_position, vehicle.y)}
		vehicle.last_lateral_distance = 0.0
	var safe_delta := maxf(0.0, delta)
	var substeps := maxi(1, ceili(safe_delta / (1.0 / 60.0)))
	for substep in substeps:
		_tick_step(safe_delta / substeps, player_speed, player_lane, frame_start)
	for vehicle in vehicles:
		var initial: Vector2 = frame_start[vehicle.get_instance_id()].position
		vehicle.previous_lane_position = initial.x
		vehicle.previous_y = initial.y
		vehicle.lateral_velocity = (vehicle.lane_position - initial.x) * (GameConfig.ROAD_HALF_WIDTH * 2.0 / lane_count) / maxf(0.001, safe_delta)

func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
	_core_snapshot_y = lane_events._core_y()
	_closure_birth_step_seconds = 0.0
	for vehicle in vehicles:
		vehicle.previous_lane_position = vehicle.lane_position
		vehicle.previous_y = vehicle.y
	_player_speed = player_speed
	_player_lane = player_lane
	fast_priority.refresh(vehicles)
	lane_events.scheduling_paused = fast_priority.active()
	if _may_cancel_unpublished_closure() and not _closure_can_continue():
		lane_events.cancel_warning()
	var lane_update := lane_events.tick(delta, difficulty_stage, player_lane, player_speed)
	if lane_update.began_warning:
		_core_snapshot_y = lane_events._core_y()
		_closure_birth_step_seconds = delta
	if _may_cancel_unpublished_closure() and not _closure_can_continue():
		lane_events.cancel_warning()
	_closure_birth_step_seconds = 0.0
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_next(player_speed, player_lane)
		_spawn_cooldown = _spawn_interval_for_stage()
	for vehicle in vehicles:
		var identity := vehicle.get_instance_id()
		if not frame_start.has(identity) or frame_start[identity].generation != vehicle.motion_generation:
			frame_start[identity] = {"generation":vehicle.motion_generation,"position":Vector2(vehicle.lane_position, vehicle.y)}
			vehicle.last_lateral_distance = 0.0
	# Resolve competing intents in a stable order, never caller array order.
	vehicles.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	fast_priority.coordinate_stagger(self)
	# Make every normal vehicle decide from the same start-of-frame snapshot.
	# Advancing one vehicle before another decides would mix two time points and
	# could admit an unsafe lane change between equal-speed vehicles.
	for vehicle in vehicles:
		if vehicle.kind != Kind.FAST_OVERTAKE:
			_update_normal_lane_behavior(vehicle, delta)
	for vehicle in vehicles:
		if vehicle.kind == Kind.FAST_OVERTAKE:
			_update_fast_overtaker(vehicle, delta, player_speed)
	_update_traffic_speeds(delta)
	for vehicle in vehicles:
		_advance_normal_vehicle(vehicle, delta, player_speed)
		vehicle.has_entered_viewport = vehicle.has_entered_viewport or (vehicle.y + vehicle.half_length >= 0.0 and vehicle.y - vehicle.half_length <= _viewport_height)
	for vehicle in vehicles:
		vehicle.last_lateral_distance += absf(vehicle.lane_position - vehicle.previous_lane_position)
		vehicle.impact_speed_offset = move_toward(vehicle.impact_speed_offset, 0.0, 90.0 * delta)
	for vehicle in vehicles:
		if vehicle.kind != Kind.FAST_OVERTAKE:
			_recheck_lane_change_commitment_after_advance(vehicle)
	# A warning that was safe at the start of the frame can become unsafe after
	# fixed-speed traffic advances. Recheck the resulting frame before keeping it.
	if _may_cancel_unpublished_closure() and not _closure_can_continue():
		lane_events.cancel_warning()
	_recycle_offscreen_vehicles()
	fast_priority.refresh(vehicles)

func acquire_vehicle(kind: int, lane: int, y: float, assigned_cruise_speed: float = -1.0) -> TrafficVehicle:
	var target_lane := _target_lane_for(kind, lane)
	var visual_variant := _visual_variant_cursor % 2 if kind == Kind.STEADY_SLOW else 0
	if kind == Kind.STEADY_SLOW:
		_visual_variant_cursor += 1
	var vehicle: TrafficVehicle
	if _pool.is_empty():
		vehicle = TrafficVehicle.new(kind, lane, y, target_lane, visual_variant, assigned_cruise_speed)
		allocated_vehicle_count += 1
	else:
		vehicle = _pool.pop_back()
		vehicle.configure(kind, lane, y, target_lane, visual_variant, assigned_cruise_speed)
	return vehicle

func reset(run_seed: int = -1) -> void:
	fast_priority.reset()
	_closure_birth_step_seconds = 0.0
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
	lane_events.set_viewport_height(_viewport_height)

func set_spawn_exclusion_zones(zones: Array[Vector2]) -> void:
	_spawn_exclusion_zones.assign(zones)

func set_guidance_reserved_lanes(lanes: Array[int]) -> void:
	lane_events.set_guidance_reserved_lanes(lanes)

func fast_priority_lanes() -> Array[int]:
	return fast_priority.reserved_lanes()

func configure_difficulty(profile: Dictionary) -> void:
	spawn_interval_multiplier = maxf(0.1, float(profile.traffic_interval_multiplier))
	difficulty_event_interval_multiplier = maxf(0.1, float(profile.event_interval_multiplier))
	random_lane_change_probability = clampf(float(profile.get("random_lane_change_probability", 0.0)), 0.0, 1.0)
	target_active_vehicles = clampi(int(profile.get("traffic_active_target", 6)), 1, max_active_vehicles - 1)
	lane_warning_multiplier = clampf(float(profile.get("lane_warning_multiplier", 1.0)), 0.85, 1.5)
	early_fast_overtakers = bool(profile.get("early_fast_overtakers", false))
	lane_events.event_limit = clampi(int(profile.get("construction_event_limit", lane_events.event_limit)), 2, 4)
	lane_events.configure_double_lane_probability(float(profile.get("double_lane_closure_probability", 0.0)))
	_apply_event_interval()

func configure_track(profile: Dictionary) -> void:
	track_pattern = StringName(profile.get("traffic_pattern", &"coast_flow"))
	track_event_interval_multiplier = maxf(0.1, float(profile.get("lane_event_interval_multiplier", 1.0)))
	track_spawn_interval_multiplier = maxf(0.1, float(profile.get("traffic_interval_multiplier", 1.0)))
	_apply_event_interval()

func update_vehicle(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	_player_speed = player_speed
	_core_snapshot_y = lane_events._core_y()
	if vehicle.kind == Kind.FAST_OVERTAKE:
		_update_fast_overtaker(vehicle, delta, player_speed)
	else:
		_update_normal_lane_behavior(vehicle, delta)
	vehicle.actual_world_speed = _following_speed(vehicle, delta)
	_advance_normal_vehicle(vehicle, delta, player_speed)
	vehicle.impact_speed_offset = move_toward(vehicle.impact_speed_offset, 0.0, 90.0 * maxf(0.0, delta))
	_recheck_lane_change_commitment_after_advance(vehicle)

func _update_normal_lane_behavior(vehicle: TrafficVehicle, delta: float) -> void:
	fast_priority.prepare_normal(self, vehicle)
	_update_lane_change_lifecycle(vehicle, delta)
	if vehicle.lane_change_enabled:
		var lateral_delta := delta
		if lane_events.is_lane_blocked(vehicle.target_lane) and not vehicle.change_started:
			_cancel_planned_lane_change(vehicle)
		elif vehicle.warning_started and not vehicle.change_started and (
			not _lane_change_warning_preserves_immediate_player_options(vehicle)
			or _lane_change_overlaps_guidance(vehicle)
			or _lane_change_creates_wall(vehicle)
		):
			_cancel_planned_lane_change(vehicle)
		else:
			var lane_change_is_visible := _is_lane_change_visible(vehicle)
			if not vehicle.warning_started and lane_change_is_visible and _can_commit_lane_change_warning(vehicle):
				vehicle.warning_started = true
				vehicle.lane_change_reservation_active = true
				vehicle.warning_remaining = lane_change_warning_duration()
			if vehicle.warning_started and not vehicle.change_started and not lane_change_is_visible:
				_cancel_planned_lane_change(vehicle)
				return
			if vehicle.warning_remaining > 0.0:
				var warning_before_tick := vehicle.warning_remaining
				vehicle.warning_remaining = maxf(0.0, vehicle.warning_remaining - delta)
				lateral_delta = maxf(0.0, delta - warning_before_tick)
			if vehicle.warning_started and is_zero_approx(vehicle.warning_remaining) and not vehicle.change_started:
				if _is_lane_change_visible(vehicle) and is_lane_change_safe(vehicle):
					vehicle.change_started = true
					lane_change_started_count += 1
				else:
					_cancel_planned_lane_change(vehicle)
		if vehicle.change_started:
			vehicle.lane_position = move_toward(vehicle.lane_position, float(vehicle.target_lane), NORMAL_LANE_CHANGE_SPEED * lateral_delta)
			if is_equal_approx(vehicle.lane_position, float(vehicle.target_lane)):
				_complete_normal_lane_change(vehicle)

func _advance_normal_vehicle(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	var relative_speed := player_speed - vehicle.actual_world_speed
	vehicle.y += relative_speed * GameConfig.ROAD_SCROLL_MULTIPLIER * delta

func _update_traffic_speeds(delta: float) -> void:
	# Front-to-back resolution uses one position snapshot and the already
	# resolved leader speed. Array insertion order cannot change a queue.
	var ordered := vehicles.duplicate()
	ordered.sort_custom(func(a, b): return a.y < b.y if not is_equal_approx(a.y, b.y) else a.get_instance_id() < b.get_instance_id())
	for vehicle in ordered:
		vehicle.actual_world_speed = _following_speed(vehicle, delta)

func _following_speed(vehicle: TrafficVehicle, delta: float) -> float:
	var target := _following_target_speed(vehicle)
	var rate := NPC_BRAKING if target < vehicle.actual_world_speed else NPC_ACCELERATION
	return move_toward(vehicle.actual_world_speed, target, maxf(0.0, delta) * rate)

func _following_target_speed(vehicle: TrafficVehicle) -> float:
	# The transient impact changes the target once. It is not added again to
	# motion already represented by actual_world_speed on the following frame.
	var target := maxf(0.0, vehicle.cruise_speed + vehicle.impact_speed_offset)
	target = minf(target, fast_priority.cooperative_target_speed(self, vehicle))
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / lane_count
	for other in vehicles:
		if other == vehicle or other.y >= vehicle.y:
			continue
		var shared_reservation := false
		for reserved in TrafficSafetyPolicy.reserved_lanes(vehicle):
			shared_reservation = shared_reservation or TrafficSafetyPolicy.reserved_lanes(other).has(reserved)
		if not shared_reservation and absf(vehicle.lane_position - other.lane_position) * lane_width >= vehicle.half_width + other.half_width + TrafficSafetyPolicy.BODY_MARGIN:
			continue
		var free_gap := vehicle.y - other.y - vehicle.half_length - other.half_length - maxf(minimum_lane_gap, FOLLOWING_BODY_MARGIN)
		target = minf(target, _safe_following_speed(free_gap, other.actual_world_speed))
	if lane_events.state != LaneEventDirector.State.IDLE:
		# Query the world core even before its marker enters the rendering window.
		# Its screen motion is player scrolling; its absolute road speed is zero.
		var core_y := _core_snapshot_y
		for closed_lane in lane_events.closed_lanes():
			var core_half_width := lane_width * GameConfig.LANE_EVENT_CORE_HALF_LANE_RATIO
			if core_y < vehicle.y and absf(vehicle.lane_position - closed_lane) * lane_width < vehicle.half_width + core_half_width:
				var free_gap := vehicle.y - core_y - maxf(62.0, vehicle.half_length + 20.0) - FOLLOWING_BODY_MARGIN
				target = minf(target, _safe_following_speed(free_gap, 0.0))
	if vehicle.kind == Kind.FAST_OVERTAKE:
		var player_y := TrackGeometry.player_y(_viewport_height)
		var needs_warning := not vehicle.arrival_warning_started or vehicle.overtake_warning_remaining > 0.0
		var needs_escape := not _can_release_fast_overtaker(vehicle)
		if vehicle.y > player_y and (needs_warning or needs_escape):
			# The moving player is an actual safety constraint, not a camera lock.
			# Limit closing speed through braking; never assign y to a staging point.
			var free_gap := vehicle.y - player_y - collision_distance_for(vehicle)
			# Without an escape corridor, cover the player's full reaction travel.
			# With one available, shared travel need not prevent a visible warning.
			var arrival_target := _safe_following_speed(free_gap, _player_speed) if needs_escape else _safe_player_following_speed(free_gap, _player_speed)
			target = minf(target, arrival_target)
	target = minf(target, _construction_following_target(vehicle))
	target = minf(target, _wall_following_target(vehicle))
	return target

func _construction_following_target(vehicle: TrafficVehicle) -> float:
	var closed := lane_events.navigation_blocked_lanes(vehicle.y, minimum_lane_gap, _viewport_height)
	if closed.is_empty():
		return INF
	var target := INF
	for other in vehicles:
		if other == vehicle or other.y >= vehicle.y:
			continue
		var occupied := closed.duplicate()
		for actor in [vehicle, other]:
			for reserved in TrafficSafetyPolicy.reserved_lanes(actor):
				if not occupied.has(reserved): occupied.append(reserved)
		if occupied.size() < lane_count:
			continue
		# A closed road already consumes one escape lane. The remaining cars
		# cannot be only 120px apart: their two player-collision windows overlap.
		var escape_gap := collision_distance_for(vehicle) + collision_distance_for(other) + 0.5
		var free_gap := vehicle.y - other.y - escape_gap
		target = minf(target, _safe_following_speed(free_gap, other.actual_world_speed))
	return target

func _wall_following_target(vehicle: TrafficVehicle) -> float:
	var target := INF
	for other in vehicles:
		if other == vehicle or other.y >= vehicle.y:
			continue
		var occupied := TrafficSafetyPolicy.reserved_lanes(vehicle)
		for lane in TrafficSafetyPolicy.reserved_lanes(other):
			if not occupied.has(lane):
				occupied.append(lane)
		if occupied.size() >= lane_count:
			var free_gap := vehicle.y - other.y - TrafficSafetyPolicy.WALL_LONGITUDINAL_CLEARANCE - 0.5
			target = minf(target, _safe_following_speed(free_gap, other.actual_world_speed))
	for first_index in vehicles.size():
		var first := vehicles[first_index]
		if first == vehicle:
			continue
		for second_index in range(first_index + 1, vehicles.size()):
			var second := vehicles[second_index]
			if second == vehicle:
				continue
			# The other two lanes may straddle this car. Their ordering changes
			# during a pass; dropping a rear member would release the middle car
			# or delay the third car's braking until a wall is unavoidable.
			var front: TrafficVehicle = null
			for other in [first, second]:
				if other.y < vehicle.y and (front == null or other.y < front.y): front = other
			if front == null:
				continue
			var horizon := BRAKING_REACTION_SECONDS + vehicle.actual_world_speed / NPC_BRAKING
			var pair_delta := first.y - second.y
			var future_pair_delta := pair_delta - (first.actual_world_speed - second.actual_world_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER * horizon
			# Equal longitudinal position may occur between two separated
			# endpoints. Sign crossing makes that interior minimum exactly zero.
			var minimum_pair_gap := 0.0 if pair_delta * future_pair_delta <= 0.0 else minf(absf(pair_delta), absf(future_pair_delta))
			if minimum_pair_gap >= TrafficSafetyPolicy.WALL_LONGITUDINAL_CLEARANCE:
				continue
			var occupied := TrafficSafetyPolicy.reserved_lanes(vehicle)
			for other in [first, second]:
				for lane in TrafficSafetyPolicy.reserved_lanes(other):
					if not occupied.has(lane):
						occupied.append(lane)
			if occupied.size() < lane_count:
				continue
			var free_gap := vehicle.y - front.y - TrafficSafetyPolicy.WALL_LONGITUDINAL_CLEARANCE - 0.5
			target = minf(target, _safe_following_speed(free_gap, front.actual_world_speed))
	return target

func _safe_following_speed(free_gap: float, leader_speed: float) -> float:
	var reaction_speed := NPC_BRAKING * BRAKING_REACTION_SECONDS
	return maxf(0.0, sqrt(reaction_speed * reaction_speed + maxf(0.0, leader_speed) * maxf(0.0, leader_speed) + 2.0 * NPC_BRAKING * maxf(0.0, free_gap) / GameConfig.ROAD_SCROLL_MULTIPLIER) - reaction_speed)

func _safe_player_following_speed(free_gap: float, player_speed: float) -> float:
	# Shared travel during reaction must not become a permanent screen gap.
	# Budget relative reaction travel plus the two absolute stopping distances.
	var reaction_speed := NPC_BRAKING * BRAKING_REACTION_SECONDS
	var leader_with_reaction := maxf(0.0, player_speed) + reaction_speed
	return maxf(0.0, sqrt(leader_with_reaction * leader_with_reaction + 2.0 * NPC_BRAKING * maxf(0.0, free_gap) / GameConfig.ROAD_SCROLL_MULTIPLIER) - reaction_speed)

func _lane_change_preserves_player_options(vehicle: TrafficVehicle) -> bool:
	var player_y := TrackGeometry.player_y(_viewport_height)
	var clearance := maxf(GameConfig.COLLISION_LONGITUDINAL_DISTANCE, _player_speed * 0.5)
	return _player_keeps_escape_after_lane_change(vehicle, player_y, clearance)

func _can_commit_lane_change_warning(vehicle: TrafficVehicle) -> bool:
	return is_lane_change_safe(vehicle) \
		and _lane_change_preserves_player_options(vehicle) \
		and _lane_change_starts_while_visible(vehicle) \
		and _lane_change_transition_is_safe(vehicle) \
		and not _lane_change_overlaps_guidance(vehicle) \
		and not _lane_change_creates_wall(vehicle)

func _lane_change_starts_while_visible(vehicle: TrafficVehicle) -> bool:
	var relative_speed := (_player_speed - vehicle.actual_world_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER
	var start_y := vehicle.y + relative_speed * lane_change_warning_duration()
	return start_y >= LANE_CHANGE_WARNING_ENTRY_Y and start_y <= _viewport_height - vehicle.half_length

func _lane_change_transition_is_safe(vehicle: TrafficVehicle) -> bool:
	var player_y := TrackGeometry.player_y(_viewport_height)
	if vehicle.y > player_y - collision_distance_for(vehicle):
		return false
	if _player_keeps_escape_with_candidate_lanes(
		vehicle,
		player_y,
		GameConfig.COLLISION_LONGITUDINAL_DISTANCE,
		player_y,
		[vehicle.lane, vehicle.target_lane]
	):
		return true
	var relative_speed := (_player_speed - vehicle.actual_world_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER
	if relative_speed <= 0.0:
		return true
	return _lane_change_completion_y(vehicle) <= player_y - collision_distance_for(vehicle)

func _recheck_lane_change_commitment_after_advance(vehicle: TrafficVehicle) -> void:
	if vehicle.lane_change_enabled \
		and vehicle.warning_started \
		and not vehicle.change_started \
		and (
			not _lane_change_warning_preserves_immediate_player_options(vehicle)
			or _lane_change_overlaps_guidance(vehicle)
			or _lane_change_creates_wall(vehicle)
		):
		_cancel_planned_lane_change(vehicle)

func _lane_change_warning_preserves_immediate_player_options(vehicle: TrafficVehicle) -> bool:
	var player_y := TrackGeometry.player_y(_viewport_height)
	return _player_keeps_escape_with_candidate_lanes(
		vehicle,
		player_y,
		GameConfig.COLLISION_LONGITUDINAL_DISTANCE,
		vehicle.y,
		[vehicle.lane, vehicle.target_lane]
	)

func _lane_change_completion_y(vehicle: TrafficVehicle) -> float:
	var relative_speed := (_player_speed - vehicle.actual_world_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER
	return vehicle.y + relative_speed * _lane_change_remaining_seconds(vehicle)

func _lane_change_remaining_seconds(vehicle: TrafficVehicle) -> float:
	var warning_time := vehicle.warning_remaining if vehicle.warning_started else lane_change_warning_duration()
	var lateral_time := absf(float(vehicle.target_lane) - vehicle.lane_position) / NORMAL_LANE_CHANGE_SPEED
	return warning_time + lateral_time

func _cancel_planned_lane_change(vehicle: TrafficVehicle) -> void:
	# Started changes finish continuously; callers may only release a waiting
	# reservation. No cancellation is allowed to move a vehicle sideways.
	if vehicle.change_started:
		return
	vehicle.target_lane = vehicle.lane
	vehicle.lane_change_enabled = false
	vehicle.warning_started = false
	vehicle.warning_remaining = 0.0
	vehicle.change_started = false
	vehicle.lane_change_reservation_active = false
	vehicle.lane_change_cooldown = LANE_CHANGE_COOLDOWN

func _complete_normal_lane_change(vehicle: TrafficVehicle) -> void:
	vehicle.lane = vehicle.target_lane
	vehicle.lane_position = float(vehicle.lane)
	vehicle.lane_change_enabled = false
	vehicle.warning_started = false
	vehicle.warning_remaining = 0.0
	vehicle.change_started = false
	vehicle.lane_change_reservation_active = false
	vehicle.lane_change_cooldown = LANE_CHANGE_COOLDOWN

func _update_lane_change_lifecycle(vehicle: TrafficVehicle, delta: float) -> void:
	vehicle.lane_change_cooldown = maxf(0.0, vehicle.lane_change_cooldown - delta)
	if vehicle.warning_started and not vehicle.lane_change_reservation_active:
		vehicle.lane_change_reservation_active = true
		vehicle.lane_change_wait_seconds = 0.0
	if vehicle.lane_change_reservation_active and not vehicle.change_started:
		vehicle.lane_change_wait_seconds += maxf(0.0, delta)
		if vehicle.lane_change_wait_seconds >= LANE_CHANGE_WAIT_LIMIT - 0.0000001:
			_cancel_planned_lane_change(vehicle)

func _update_fast_overtaker(vehicle: TrafficVehicle, delta: float, player_speed: float) -> void:
	_update_lane_change_lifecycle(vehicle, delta)
	var staging_y: float = minf(TrackGeometry.fast_overtake_staging_y(_viewport_height), _viewport_height - vehicle.half_length)
	if not vehicle.arrival_warning_started and vehicle.y <= staging_y:
		vehicle.arrival_warning_started = true
		vehicle.overtake_warning_remaining = 1.0
	elif vehicle.arrival_warning_started and vehicle.overtake_warning_remaining > 0.0 and _is_lane_change_visible(vehicle):
		vehicle.overtake_warning_remaining = maxf(0.0, vehicle.overtake_warning_remaining - delta)
	if vehicle.lane_change_enabled:
		_advance_fast_lane_change(vehicle, delta)
	elif _is_lane_change_visible(vehicle):
		_try_plan_fast_lane_change(vehicle)

func _try_plan_fast_lane_change(overtaker: TrafficVehicle) -> bool:
	if overtaker.lane_change_cooldown > 0.0:
		return false
	var blocker := _nearest_fast_route_blocker(overtaker, _fast_planning_distance(overtaker))
	if blocker == null or fast_priority.waiting_for_yield(self, overtaker, blocker):
		return false
	var route_lane: int = _best_fast_route_lane(overtaker)
	if route_lane < 0:
		return false
	_begin_fast_lane_change(overtaker, route_lane)
	return true

func _fast_planning_distance(overtaker: TrafficVehicle) -> float:
	# Signal and merge before entering the slow leader's braking horizon.
	var closing_speed := maxf(0.0, overtaker.cruise_speed - NORMAL_SPEED_MIN)
	var stopping_gap := maxf(0.0, overtaker.cruise_speed * overtaker.cruise_speed - NORMAL_SPEED_MIN * NORMAL_SPEED_MIN) / (2.0 * NPC_BRAKING)
	var planning_time := BRAKING_REACTION_SECONDS + FAST_ROUTE_WARNING_SECONDS + 1.0 / FAST_LANE_CHANGE_SPEED
	return maxf(FAST_ROUTE_LOOKAHEAD, minimum_lane_gap + overtaker.half_length * 2.0 + (stopping_gap + closing_speed * planning_time) * GameConfig.ROAD_SCROLL_MULTIPLIER)

func _nearest_fast_route_blocker(overtaker: TrafficVehicle, lookahead: float) -> TrafficVehicle:
	var nearest: TrafficVehicle = null
	var nearest_distance: float = INF
	for other in vehicles:
		if other == overtaker or not TrafficSafetyPolicy.reserved_lanes(other).has(overtaker.lane):
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
	var best_delay := INF
	for candidate_lane_value in [overtaker.lane - 1, overtaker.lane + 1]:
		var candidate_lane: int = candidate_lane_value
		if not is_lane_valid(candidate_lane) or lane_events.is_lane_blocked(candidate_lane):
			continue
		if not _fast_merge_lane_is_clear(overtaker, candidate_lane):
			continue
		if _fast_lane_change_overlaps_guidance(overtaker, candidate_lane) or _fast_lane_change_creates_wall(overtaker, candidate_lane):
			continue
		if not _fast_route_preserves_player_options(overtaker, candidate_lane):
			continue
		var clearance: float = _fast_forward_clearance(overtaker, candidate_lane)
		var passage_delay: float = fast_priority.passage_delay(self,overtaker,candidate_lane)
		var avoids_player: bool = candidate_lane != _player_lane
		var best_avoids_player: bool = best_lane >= 0 and best_lane != _player_lane
		if passage_delay < best_delay or (is_equal_approx(passage_delay,best_delay) and (clearance > best_clearance or (is_equal_approx(clearance, best_clearance) and avoids_player and not best_avoids_player))):
			best_lane = candidate_lane
			best_clearance = clearance
			best_delay = passage_delay
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
	var clearance: float = _fast_planning_distance(overtaker) * 2.0
	for other in vehicles:
		if other == overtaker or not TrafficSafetyPolicy.reserved_lanes(other).has(candidate_lane):
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
	if not overtaker.lane_change_reservation_active:
		overtaker.lane_change_reservation_active = true
		overtaker.lane_change_wait_seconds = 0.0

func _fast_lane_change_overlaps_guidance(overtaker: TrafficVehicle, target_lane: int) -> bool:
	return _overlaps_exclusion_at(target_lane, overtaker.y, overtaker.half_length) \
		or _overlaps_exclusion_at(target_lane, _fast_lane_change_completion_y(overtaker, target_lane), overtaker.half_length)

func _fast_lane_change_creates_wall(overtaker: TrafficVehicle, target_lane: int) -> bool:
	var reserved: Array[int] = [overtaker.lane, target_lane]
	if _construction_corridor_is_reserved(overtaker, reserved):
		return true
	var duration := FAST_ROUTE_WARNING_SECONDS + absf(target_lane - overtaker.lane_position) / FAST_LANE_CHANGE_SPEED
	return TrafficSafetyPolicy.would_form_full_lane_wall_during(vehicles, overtaker, lane_count, reserved, duration, GameConfig.ROAD_SCROLL_MULTIPLIER)

func _fast_lane_change_completion_y(overtaker: TrafficVehicle, target_lane: int) -> float:
	var lateral_time := absf(float(target_lane) - overtaker.lane_position) / FAST_LANE_CHANGE_SPEED
	var relative_speed := (_player_speed - overtaker.actual_world_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER
	return overtaker.y + relative_speed * (FAST_ROUTE_WARNING_SECONDS + lateral_time)

func _advance_fast_lane_change(overtaker: TrafficVehicle, delta: float) -> void:
	if lane_events.is_lane_blocked(overtaker.target_lane) and not overtaker.change_started:
		_cancel_fast_lane_change(overtaker)
		return
	if not overtaker.change_started and not _fast_route_preserves_player_options(overtaker, overtaker.target_lane):
		_cancel_fast_lane_change(overtaker)
		return
	if overtaker.warning_remaining > 0.0:
		if _is_lane_change_visible(overtaker):
			overtaker.warning_remaining = maxf(0.0, overtaker.warning_remaining - delta)
		else:
			overtaker.warning_remaining = FAST_ROUTE_WARNING_SECONDS
		return
	if not overtaker.change_started:
		if not _is_lane_change_visible(overtaker) or not is_lane_change_safe(overtaker):
			_cancel_fast_lane_change(overtaker)
			return
		overtaker.change_started = true
		lane_change_started_count += 1
	overtaker.lane_position = move_toward(overtaker.lane_position, float(overtaker.target_lane), FAST_LANE_CHANGE_SPEED * delta)
	if is_equal_approx(overtaker.lane_position, float(overtaker.target_lane)):
		_complete_fast_lane_change(overtaker)

func _complete_fast_lane_change(overtaker: TrafficVehicle) -> void:
	_complete_normal_lane_change(overtaker)

func _cancel_fast_lane_change(overtaker: TrafficVehicle) -> void:
	_cancel_planned_lane_change(overtaker)

func _constrain_fast_overtaker_y(overtaker: TrafficVehicle, proposed_y: float) -> float:
	var constrained_y := _body_safe_fast_y(overtaker, proposed_y)
	var wall_safe_y := TrafficSafetyPolicy.rear_y_outside_full_wall(_safety_relevant_vehicles(), overtaker, lane_count, constrained_y, TrafficSafetyPolicy.reserved_lanes(overtaker))
	constrained_y = maxf(constrained_y, wall_safe_y)
	for other in vehicles:
		if other == overtaker or other.lane != overtaker.lane or other.y >= overtaker.y:
			continue
		var required_gap: float = minimum_lane_gap + overtaker.half_length + other.half_length
		constrained_y = maxf(constrained_y, other.y + required_gap)
	if constrained_y < overtaker.y and _player_escape_count_around_fast_at_y(overtaker, constrained_y) == 0:
		return overtaker.y
	return constrained_y

func _body_safe_fast_y(overtaker: TrafficVehicle, proposed_y: float) -> float:
	var safe_y := proposed_y
	var lane_width: float = GameConfig.ROAD_HALF_WIDTH * 2.0 / float(lane_count)
	for _iteration in range(maxi(1, vehicles.size())):
		var changed := false
		for other in _safety_relevant_vehicles():
			if other == overtaker:
				continue
			var lateral_distance := absf(overtaker.lane_position - other.lane_position) * lane_width
			if lateral_distance >= overtaker.half_width + other.half_width + TrafficSafetyPolicy.BODY_MARGIN:
				continue
			var required_gap: float = overtaker.half_length + other.half_length + TrafficSafetyPolicy.BODY_MARGIN + 0.5
			if absf(safe_y - other.y) >= required_gap:
				continue
			safe_y = other.y - required_gap if safe_y <= other.y else other.y + required_gap
			changed = true
		if not changed:
			break
	return safe_y

func _resolve_fast_safety_after_normal_advance() -> void:
	# Normal traffic can enter a lane after the fast-vehicle phase. Re-evaluate
	# until every fast vehicle is stable because moving one rearward may affect
	# the next fast vehicle's safe following position.
	for _iteration in range(maxi(1, vehicles.size())):
		var changed := false
		for vehicle in vehicles:
			if vehicle.kind != Kind.FAST_OVERTAKE:
				continue
			var safe_y := _constrain_fast_overtaker_y(vehicle, vehicle.y)
			if not is_equal_approx(safe_y, vehicle.y):
				vehicle.y = safe_y
				changed = true
		if not changed:
			break

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
		if other.lane == vehicle.target_lane or reserves_target:
			var speed_gap_safe := vehicles_keep_safe_gap_until_recycle(vehicle, other, _player_speed) if vehicle.kind == Kind.FAST_OVERTAKE else vehicles_keep_or_open_gap(vehicle, other)
			if not vehicles_have_minimum_gap(vehicle, other) or not speed_gap_safe:
				return false
	return not _lane_change_overlaps_guidance(vehicle) and not _lane_change_creates_wall(vehicle)

func has_full_lane_wall() -> bool:
	return TrafficSafetyPolicy.has_full_lane_wall(_safety_relevant_vehicles(), lane_count)

func has_vehicle_overlap() -> bool:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / float(lane_count)
	return TrafficSafetyPolicy.has_body_overlap(_safety_relevant_vehicles(), lane_width)

func _safety_relevant_vehicles() -> Array:
	var relevant: Array = []
	var maximum_y := TrackGeometry.normal_recycle_y(_viewport_height)
	for vehicle in vehicles:
		if vehicle.y <= maximum_y:
			relevant.append(vehicle)
	return relevant

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
	for closed_lane in lane_events.navigation_blocked_lanes(y, clearance, _viewport_height):
		blocked.append(closed_lane)
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
	var event_clearance := maxf(clearance, _player_speed * 0.5)
	for closed_lane in lane_events.navigation_blocked_lanes(player_y, event_clearance, _viewport_height):
		blocked.append(closed_lane)
	for vehicle in vehicles:
		if absf(vehicle.y - player_y) >= clearance + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
			continue
		if vehicle.kind == Kind.FAST_OVERTAKE and vehicle.overtake_warning_remaining > 0.0 and clearance <= GameConfig.COLLISION_LONGITUDINAL_DISTANCE:
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

func braking_reaction_clearance(player_speed: float) -> float:
	var slowest_traffic_speed := NORMAL_SPEED_MIN * TrafficVehicle.TRUCK_CRUISE_SPEED_MULTIPLIER
	var closing_speed := maxf(0.0, player_speed - slowest_traffic_speed)
	var braking_distance := closing_speed * closing_speed / maxf(1.0, 2.0 * GameConfig.BRAKING) * GameConfig.ROAD_SCROLL_MULTIPLIER
	var reaction_distance := closing_speed * BRAKING_REACTION_SECONDS * GameConfig.ROAD_SCROLL_MULTIPLIER
	return maxf(minimum_lane_gap, GameConfig.COLLISION_LONGITUDINAL_DISTANCE + reaction_distance + braking_distance)

func _can_release_fast_overtaker(overtaker: TrafficVehicle) -> bool:
	var planned_lane: int = overtaker.target_lane if overtaker.lane_change_enabled else -1
	# Release means committing to pass the player, not occupying a distant lane.
	# Reserve the passing lane at the player before granting acceleration.
	return _player_escape_count_around_fast_at_y(overtaker, TrackGeometry.player_y(_viewport_height), planned_lane) > 0

func _fast_route_preserves_player_options(overtaker: TrafficVehicle, planned_lane: int) -> bool:
	var options_after: int = _player_escape_count_around_fast(overtaker, planned_lane)
	return options_after > 0

func _player_has_escape_around_fast(overtaker: TrafficVehicle, planned_lane: int = -1) -> bool:
	return _player_escape_count_around_fast(overtaker, planned_lane) > 0

func _player_escape_count_around_fast(overtaker: TrafficVehicle, planned_lane: int = -1) -> int:
	return _player_escape_count_around_fast_at_y(overtaker, overtaker.y, planned_lane)

func _player_escape_count_around_fast_at_y(overtaker: TrafficVehicle, overtaker_y: float, planned_lane: int = -1) -> int:
	var player_y := TrackGeometry.player_y(_viewport_height)
	var clearance := maxf(minimum_lane_gap, _player_speed * 0.5)
	var blocked: Array[int] = []
	if absf(overtaker_y - player_y) < clearance + overtaker.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
		blocked.append(overtaker.lane)
		if is_lane_valid(planned_lane) and not blocked.has(planned_lane):
			blocked.append(planned_lane)
	for closed_lane in lane_events.navigation_blocked_lanes(player_y, clearance, _viewport_height):
		if not blocked.has(closed_lane):
			blocked.append(closed_lane)
	for vehicle in vehicles:
		if vehicle == overtaker or absf(vehicle.y - player_y) >= clearance + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH:
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
	fast_priority.refresh(vehicles)
	if fast_priority.needs_clearance_window(self):
		return
	if vehicles.size() >= target_active_vehicles:
		return
	var kind := _kind_for_next_spawn()
	if kind == Kind.FAST_OVERTAKE and fast_priority.active():
		return
	var lane := _fast_spawn_lane(player_lane) if kind == Kind.FAST_OVERTAKE else _random.randi_range(0, lane_count - 1)
	if kind != Kind.FAST_OVERTAKE and fast_priority.active():
		for offset in lane_count:
			var available_lane := (lane + offset) % lane_count
			if not fast_priority.reserved_lanes().has(available_lane) and not lane_events.is_lane_blocked(available_lane):
				lane = available_lane
				break
	var y := TrackGeometry.fast_overtake_spawn_y(_viewport_height) if kind == Kind.FAST_OVERTAKE else -minimum_spawn_distance
	var candidate := acquire_vehicle(kind, lane, y, _world_speed_for_spawn(kind, lane, y))
	# A newly arriving fast car may begin below its desired speed when the
	# player/queue already occupies its braking horizon. Later changes are finite.
	if kind == Kind.FAST_OVERTAKE:
		var best_lane := -1
		var best_clearance := -INF
		# Existing cars remain untouched. Try real safe entrances on both sides;
		# selecting a pass corridor prevents spawning into a conservative queue.
		for offset in lane_count:
			var trial_lane := (lane + offset) % lane_count
			candidate.lane = trial_lane
			candidate.target_lane = trial_lane
			candidate.lane_position = float(trial_lane)
			candidate.previous_lane_position = candidate.lane_position
			candidate.actual_world_speed = _following_target_speed(candidate)
			if not _can_spawn_candidate(candidate, player_speed, player_lane): continue
			var clearance := _fast_forward_clearance(candidate, trial_lane)
			if trial_lane == player_lane: clearance -= FAST_ROUTE_LOOKAHEAD
			if clearance > best_clearance:
				best_lane = trial_lane
				best_clearance = clearance
		if best_lane < 0:
			_pool.append(candidate)
			return
		candidate.lane = best_lane
		candidate.target_lane = best_lane
		candidate.lane_position = float(best_lane)
		candidate.previous_lane_position = candidate.lane_position
		candidate.actual_world_speed = _following_target_speed(candidate)
	_plan_random_lane_change(candidate)
	if fast_priority.active() and fast_priority.reserved_lanes().has(candidate.target_lane):
		_cancel_planned_lane_change(candidate)
	if not _can_spawn_candidate(candidate, player_speed, player_lane):
		_pool.append(candidate)
		return
	candidate.spawn_was_fair = true
	vehicles.append(candidate)
	fast_priority.refresh(vehicles)
	if candidate.kind == Kind.STEADY_SLOW and candidate.lane_change_enabled:
		random_lane_change_planned_count += 1
	_spawn_history.append("%d:%d:%d" % [kind, candidate.lane, roundi(candidate.cruise_speed)])

func _fast_spawn_lane(player_lane: int) -> int:
	return lane_count - 1 if player_lane < lane_count / 2 else 0

func _world_speed_for_spawn(kind: int, lane: int = -1, y: float = 0.0) -> float:
	if kind == Kind.FAST_OVERTAKE:
		return TrafficVehicle._cruise_speed_for_kind(kind)
	var normal_speed := float(_random.randi_range(roundi(NORMAL_SPEED_MIN / NORMAL_SPEED_STEP), roundi(NORMAL_SPEED_MAX / NORMAL_SPEED_STEP)) * NORMAL_SPEED_STEP)
	if kind == Kind.TRUCK or not is_lane_valid(lane):
		return normal_speed * TrafficVehicle.TRUCK_CRUISE_SPEED_MULTIPLIER if kind == Kind.TRUCK else normal_speed
	var ahead_limit := NORMAL_SPEED_MAX
	var behind_floor := NORMAL_SPEED_MIN
	for vehicle in vehicles:
		if vehicle.kind == Kind.FAST_OVERTAKE or abs(vehicle.lane - lane) > 1:
			continue
		if vehicle.y >= y:
			behind_floor = maxf(behind_floor, vehicle.cruise_speed)
		else:
			ahead_limit = minf(ahead_limit, vehicle.cruise_speed)
	# Aggregate independently of Array order. In a conflicting queue, the
	# front constraint wins; actual-speed admission still protects the rear.
	normal_speed = minf(maxf(normal_speed, behind_floor), ahead_limit)
	return clampf(normal_speed, NORMAL_SPEED_MIN, NORMAL_SPEED_MAX)

func _can_spawn_vehicle(kind: int, lane: int, y: float, player_speed: float, player_lane: int) -> bool:
	if not is_lane_valid(lane):
		return false
	var candidate := TrafficVehicle.new(kind, lane, y, lane)
	return _can_spawn_candidate(candidate, player_speed, player_lane)

func _can_spawn_candidate(candidate: TrafficVehicle, player_speed: float, player_lane: int) -> bool:
	if fast_priority.active() and (candidate.kind == Kind.FAST_OVERTAKE or fast_priority.reserved_lanes().has(candidate.lane)):
		return false
	if lane_events.is_lane_blocked(candidate.lane):
		return false
	if candidate.lane_change_enabled and lane_events.is_lane_blocked(candidate.target_lane):
		return false
	if _construction_corridor_is_reserved(candidate, [candidate.lane]):
		return false
	if _overlaps_spawn_exclusion(candidate):
		return false
	if TrafficSafetyPolicy.would_create_full_lane_wall(vehicles, candidate, lane_count, candidate.y, [candidate.lane]):
		return false
	if TrafficSafetyPolicy.would_form_full_lane_wall_during(vehicles, candidate, lane_count, [candidate.lane], BRAKING_REACTION_SECONDS + candidate.actual_world_speed / NPC_BRAKING, GameConfig.ROAD_SCROLL_MULTIPLIER):
		return false
	for vehicle in vehicles:
		var shares_longitudinal_corridor: bool = vehicle.lane == candidate.lane
		var reserves_adjacent_wall_space: bool = candidate.kind != Kind.FAST_OVERTAKE and vehicle.kind != Kind.FAST_OVERTAKE and abs(vehicle.lane - candidate.lane) <= 1
		if shares_longitudinal_corridor:
			if not vehicles_have_minimum_gap(vehicle, candidate):
				return false
			# A slow offscreen birth can appear in front of an existing fast car.
			# Body spacing alone is insufficient for finite braking; use actual
			# speeds for every kind, including already-braked fast candidates.
			if not vehicles_keep_safe_gap_until_recycle(vehicle, candidate, player_speed):
				return false
		elif reserves_adjacent_wall_space:
			if not vehicles_have_minimum_gap(vehicle, candidate) or not vehicles_keep_safe_gap_until_recycle(vehicle, candidate, player_speed):
				return false
	return _has_escape_lane(candidate, player_lane, player_speed)

func _overlaps_spawn_exclusion(candidate: TrafficVehicle) -> bool:
	return _overlaps_exclusion_at(candidate.lane, candidate.y, candidate.half_length)

func _overlaps_exclusion_at(lane: int, y: float, half_length: float) -> bool:
	var clearance := GameConfig.FUEL_SPAWN_SAFETY_DISTANCE + half_length - TrafficVehicle.NORMAL_HALF_LENGTH
	for zone in _spawn_exclusion_zones:
		if int(zone.x) == lane and absf(zone.y - y) < clearance:
			return true
	return false

func _lane_change_overlaps_guidance(vehicle: TrafficVehicle) -> bool:
	return _overlaps_exclusion_at(vehicle.target_lane, vehicle.y, vehicle.half_length) \
		or _overlaps_exclusion_at(vehicle.target_lane, _lane_change_completion_y(vehicle), vehicle.half_length)

func _lane_change_creates_wall(vehicle: TrafficVehicle) -> bool:
	var reserved: Array[int] = [vehicle.lane]
	if vehicle.target_lane != vehicle.lane:
		reserved.append(vehicle.target_lane)
	if _construction_corridor_is_reserved(vehicle, reserved):
		return true
	return TrafficSafetyPolicy.would_form_full_lane_wall_during(
		_wall_policy_vehicles(vehicle),
		vehicle,
		lane_count,
		reserved,
		_lane_change_remaining_seconds(vehicle),
		GameConfig.ROAD_SCROLL_MULTIPLIER
	)

func _construction_corridor_is_reserved(candidate: TrafficVehicle, reserved: Array[int]) -> bool:
	var closed := lane_events.navigation_blocked_lanes(candidate.y, minimum_lane_gap, _viewport_height)
	if closed.is_empty():
		return false
	var occupied := closed.duplicate()
	for reserved_lane in reserved:
		if not occupied.has(reserved_lane): occupied.append(reserved_lane)
	# A warning that occupies every remaining road lane cannot be admitted.
	if occupied.size() >= lane_count:
		return true
	for other in vehicles:
		if other == candidate:
			continue
		var combined := occupied.duplicate()
		for other_lane in TrafficSafetyPolicy.reserved_lanes(other):
			if not combined.has(other_lane): combined.append(other_lane)
		if combined.size() < lane_count:
			continue
		var escape_gap := collision_distance_for(candidate) + collision_distance_for(other) + 0.5
		if absf(candidate.y - other.y) < escape_gap or not vehicles_keep_safe_gap_until_recycle(candidate, other, _player_speed):
			return true
	return false

func _wall_policy_vehicles(candidate: TrafficVehicle) -> Array:
	# An offscreen fast car can enter the reservation's future window. It may
	# not be excluded just because it is outside today's rendering rectangle.
	return vehicles

func _has_escape_lane(candidate: TrafficVehicle, player_lane: int, player_speed: float) -> bool:
	var dynamic_reaction_distance := maxf(minimum_lane_gap, player_speed)
	for candidate_lane in [player_lane - 1, player_lane + 1]:
		if not is_lane_valid(candidate_lane):
			continue
		if lane_events.is_lane_blocked(candidate_lane):
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
		return Kind.FAST_OVERTAKE if early_fast_overtakers else Kind.SIGNAL_CHANGE
	return Kind.TRUCK if difficulty_stage == 3 else Kind.FAST_OVERTAKE

func lane_change_warning_duration() -> float:
	return [0.66, 0.62, 0.60, 0.59][difficulty_stage] * lane_warning_multiplier

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
			if early_fast_overtakers:
				return [Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.STEADY_SLOW]
			return [Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE]
		2:
			match track_pattern:
				&"harbor_heavy": return [Kind.STEADY_SLOW, Kind.TRUCK, Kind.SIGNAL_CHANGE, Kind.STEADY_SLOW]
				&"ridge_weave": return [Kind.SIGNAL_CHANGE, Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE]
				&"express_fast": return [Kind.STEADY_SLOW, Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE]
				_: return [Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE]
		_:
			match track_pattern:
				&"harbor_heavy": return [Kind.TRUCK, Kind.SIGNAL_CHANGE, Kind.STEADY_SLOW, Kind.TRUCK, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE]
				&"ridge_weave": return [Kind.SIGNAL_CHANGE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE, Kind.TRUCK]
				&"express_fast": return [Kind.FAST_OVERTAKE, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE, Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE]
				_: return [Kind.SIGNAL_CHANGE, Kind.TRUCK, Kind.FAST_OVERTAKE, Kind.STEADY_SLOW, Kind.SIGNAL_CHANGE, Kind.FAST_OVERTAKE]

func _apply_event_interval() -> void:
	lane_events.configure_interval_multiplier(track_event_interval_multiplier * difficulty_event_interval_multiplier)

func _spawn_interval_for_stage() -> float:
	return [0.85, 0.72, 0.62, 0.48][difficulty_stage] * effective_spawn_interval_multiplier()

func effective_spawn_interval_multiplier() -> float:
	return track_spawn_interval_multiplier * spawn_interval_multiplier

func is_fast_spawn_fair(player_speed: float, player_lane: int) -> bool:
	return _can_spawn_vehicle(Kind.FAST_OVERTAKE, player_lane, TrackGeometry.fast_overtake_spawn_y(_viewport_height), player_speed, player_lane)

func spawn_sequence() -> String:
	return "|".join(_spawn_history)

static func fast_warning_y(vehicle_y: float) -> float:
	return vehicle_y - 52.0

func _recycle_offscreen_vehicles() -> void:
	var active: Array[TrafficVehicle] = []
	for vehicle in vehicles:
		var top_bound := -minimum_spawn_distance * 2.0 if vehicle.kind != Kind.FAST_OVERTAKE else TrackGeometry.FAST_RECYCLE_Y
		var bottom_bound := TrackGeometry.normal_recycle_y(_viewport_height)
		if vehicle.kind == Kind.FAST_OVERTAKE and not vehicle.has_entered_viewport:
			bottom_bound = TrackGeometry.fast_overtake_spawn_y(_viewport_height) + TrackGeometry.NORMAL_RECYCLE_OFFSET
		var is_offscreen := vehicle.y > bottom_bound or vehicle.y < top_bound
		if is_offscreen:
			_pool.append(vehicle)
		else:
			active.append(vehicle)
	vehicles = active

func _player_keeps_escape_after_lane_change(candidate: TrafficVehicle, player_y: float, clearance: float) -> bool:
	return _player_keeps_escape_with_candidate_lanes(
		candidate,
		player_y,
		clearance,
		_lane_change_completion_y(candidate),
		[candidate.target_lane]
	)

func _player_keeps_escape_with_candidate_lanes(candidate: TrafficVehicle, player_y: float, clearance: float, candidate_y: float, candidate_lanes: Array[int]) -> bool:
	var blocked: Array[int] = []
	var event_clearance := maxf(clearance, _player_speed * 0.5)
	for closed_lane in lane_events.navigation_blocked_lanes(player_y, event_clearance, _viewport_height):
		blocked.append(closed_lane)
	for other in vehicles:
		if other == candidate:
			continue
		var other_clearance := clearance + other.half_length - TrafficVehicle.NORMAL_HALF_LENGTH
		if absf(other.y - player_y) >= other_clearance:
			continue
		if not blocked.has(other.lane):
			blocked.append(other.lane)
		if other.lane_change_enabled and other.warning_started and not blocked.has(other.target_lane):
			blocked.append(other.target_lane)
	var candidate_clearance := clearance + candidate.half_length - TrafficVehicle.NORMAL_HALF_LENGTH
	if absf(candidate_y - player_y) < candidate_clearance:
		for candidate_lane in candidate_lanes:
			if not blocked.has(int(candidate_lane)):
				blocked.append(int(candidate_lane))
	for lane in range(lane_count):
		if abs(lane - _player_lane) <= 1 and not blocked.has(lane):
			return true
	return false

func vehicles_have_minimum_gap(first: TrafficVehicle, second: TrafficVehicle, center_distance: float = -1.0) -> bool:
	var separation := absf(first.y - second.y) if center_distance < 0.0 else center_distance
	return separation >= minimum_lane_gap + first.half_length + second.half_length

func vehicles_keep_or_open_gap(first: TrafficVehicle, second: TrafficVehicle) -> bool:
	if is_equal_approx(first.y, second.y):
		return is_equal_approx(first.actual_world_speed, second.actual_world_speed)
	var ahead := first if first.y < second.y else second
	var behind := second if ahead == first else first
	return ahead.actual_world_speed >= behind.actual_world_speed

func vehicles_keep_safe_gap_until_recycle(first: TrafficVehicle, second: TrafficVehicle, player_speed: float) -> bool:
	var ahead := first if first.y < second.y else second
	var behind := second if ahead == first else first
	var closing_speed := maxf(0.0, behind.actual_world_speed - ahead.actual_world_speed)
	var braking_distance := maxf(0.0, behind.actual_world_speed * behind.actual_world_speed - ahead.actual_world_speed * ahead.actual_world_speed) / (2.0 * NPC_BRAKING)
	var required := minimum_lane_gap + (braking_distance + closing_speed * BRAKING_REACTION_SECONDS) * GameConfig.ROAD_SCROLL_MULTIPLIER
	# Retained method name for existing callers, but there is no player-speed
	# recycle exemption: admission must leave an actually brakeable body gap.
	return absf(first.y - second.y) - first.half_length - second.half_length >= required

func collision_distance_for(vehicle: TrafficVehicle) -> float:
	return GameConfig.COLLISION_LONGITUDINAL_DISTANCE + vehicle.half_length - TrafficVehicle.NORMAL_HALF_LENGTH

func collision_lateral_distance_for(vehicle: TrafficVehicle) -> float:
	return GameConfig.COLLISION_LATERAL_DISTANCE + vehicle.half_width - TrafficVehicle.NORMAL_HALF_WIDTH

func _closure_can_continue() -> bool:
	var player_y := TrackGeometry.player_y(_viewport_height)
	if reachable_player_lanes(_player_lane, player_y, GameConfig.COLLISION_LONGITUDINAL_DISTANCE).is_empty():
		return false
	var reserved_lanes := lane_events.closed_lanes()
	if is_zero_approx(lane_events._travel_distance):
		var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / lane_count
		for vehicle in vehicles:
			for closed_lane in reserved_lanes:
				var turn_rate := FAST_LANE_CHANGE_SPEED if vehicle.kind == Kind.FAST_OVERTAKE else NORMAL_LANE_CHANGE_SPEED
				var lateral_margin := turn_rate * _closure_birth_step_seconds * lane_width if vehicle.change_started else 0.0
				if absf(vehicle.lane_position - closed_lane) * lane_width >= vehicle.half_width + lane_width * GameConfig.LANE_EVENT_CORE_HALF_LANE_RATIO + lateral_margin:
					continue
				# A scheduled core may be behind a car's center yet still cover
				# its body. Reject birth contact before the forward braking test;
				# 34px is half the existing 68px solid barrier, not its shadow.
				# New cores do not scroll until the next substep. Bound this NPC's
				# first finite acceleration/braking step before accepting the birth.
				var lowest_speed := maxf(0.0,vehicle.actual_world_speed - NPC_BRAKING * _closure_birth_step_seconds)
				var highest_speed := vehicle.actual_world_speed + NPC_ACCELERATION * _closure_birth_step_seconds
				var y_min := minf(vehicle.y,vehicle.y + (_player_speed-highest_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER * _closure_birth_step_seconds)
				var y_max := maxf(vehicle.y,vehicle.y + (_player_speed-lowest_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER * _closure_birth_step_seconds)
				var extent := vehicle.half_length + 34.0
				if y_min < lane_events._core_y() + extent and y_max > lane_events._core_y() - extent:
					return false
				var net_gap := vehicle.y - lane_events._core_y() - maxf(62.0, vehicle.half_length + 20.0) - FOLLOWING_BODY_MARGIN
				var stopping_distance := (vehicle.actual_world_speed * vehicle.actual_world_speed / (2.0 * NPC_BRAKING) + vehicle.actual_world_speed * BRAKING_REACTION_SECONDS) * GameConfig.ROAD_SCROLL_MULTIPLIER
				if net_gap >= -maxf(62.0, vehicle.half_length + 20.0) * 2.0 and net_gap < stopping_distance:
					return false
	for vehicle in vehicles:
		if vehicle.change_started and reserved_lanes.has(vehicle.target_lane):
			return false
	return true

func _may_cancel_unpublished_closure() -> bool:
	# Admission may reject an offscreen proposal. Once any world marker enters
	# view, driving/pickups cannot erase it; normal tail retirement still applies.
	return lane_events.state == LaneEventDirector.State.WARNING \
		and lane_events.cone_markers(_viewport_height).is_empty() \
		and lane_events.core_markers(_viewport_height).is_empty()

static func _event_seed(run_seed: int) -> int:
	return run_seed ^ 0x4C414E45
