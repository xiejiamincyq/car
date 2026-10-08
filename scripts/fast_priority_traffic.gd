extends RefCounted
## One overtaker owns the corridor; existing traffic yields through normal physics.
const Vehicle = preload("res://scripts/traffic_vehicle.gd")
const Safety = preload("res://scripts/traffic_safety_policy.gd")
var _owner: Vehicle = null
var _generation := -1

func reset() -> void:
	_owner = null
	_generation = -1

func refresh(vehicles: Array) -> void:
	if _owner != null and (_owner.motion_generation != _generation or not vehicles.has(_owner) or _owner.kind != Vehicle.FAST_OVERTAKE_KIND):
		reset()
	if _owner != null:
		return
	for vehicle in vehicles:
		if vehicle.kind == Vehicle.FAST_OVERTAKE_KIND and (_owner == null or vehicle.y < _owner.y):
			_owner = vehicle
	if _owner != null:
		_generation = _owner.motion_generation

func active() -> bool:
	return _owner != null

func reserved_lanes() -> Array[int]:
	return Safety.reserved_lanes(_owner) if _owner != null else []

func needs_clearance_window(host) -> bool:
	return _owner != null and _owner.y + _owner.half_length >= host.TrackGeometry.player_y(host._viewport_height) - host.minimum_lane_gap

func waiting_for_yield(host, overtaker: Vehicle, leader: Vehicle) -> bool:
	if overtaker != _owner or leader == null or leader.lane != overtaker.lane \
		or not leader.lane_change_enabled or not leader.warning_started or leader.target_lane == overtaker.lane:
		return false
	var yielding_seconds: float = leader.warning_remaining + absf(leader.target_lane - leader.lane_position) / host.NORMAL_LANE_CHANGE_SPEED
	var alternative: int = host._best_fast_route_lane(overtaker)
	return alternative < 0 or passage_delay(host,overtaker,alternative) >= yielding_seconds

func passage_delay(host, overtaker: Vehicle, lane: int) -> float:
	var delay := 0.0
	if lane != overtaker.lane:
		delay = host.FAST_ROUTE_WARNING_SECONDS + absf(lane - overtaker.lane_position) / host.FAST_LANE_CHANGE_SPEED
	var planning_distance: float = host._fast_planning_distance(overtaker)
	var obstruction_delay := 0.0
	for other in host.vehicles:
		if other == overtaker or other.y >= overtaker.y or not Safety.reserved_lanes(other).has(lane):
			continue
		if other.lane == lane and other.lane_change_enabled and other.warning_started and other.target_lane != lane:
			obstruction_delay = maxf(obstruction_delay,other.warning_remaining + absf(other.target_lane - other.lane_position) / host.NORMAL_LANE_CHANGE_SPEED)
		else:
			var closing_pixels: float = maxf(1.0,(overtaker.cruise_speed - other.actual_world_speed) * host.GameConfig.ROAD_SCROLL_MULTIPLIER)
			obstruction_delay = maxf(obstruction_delay,maxf(0.0,planning_distance - (overtaker.y - other.y)) / closing_pixels)
	return delay + obstruction_delay

func prepare_normal(host, vehicle: Vehicle) -> void:
	if _owner == null or vehicle.change_started:
		return
	var corridor := reserved_lanes()
	if vehicle.lane_change_enabled and corridor.has(vehicle.target_lane) and vehicle.target_lane != vehicle.lane:
		host._cancel_planned_lane_change(vehicle)
	if not corridor.has(vehicle.lane) or vehicle.y >= _owner.y or _owner.y - vehicle.y > host._fast_planning_distance(_owner) * 2.0:
		return
	if vehicle.lane_change_enabled or not host._is_lane_change_visible(vehicle):
		return
	# Test complete existing safety/admission rules; no kind-specific exemption.
	for target_lane in [vehicle.lane - 1, vehicle.lane + 1]:
		if not host.is_lane_valid(target_lane) or corridor.has(target_lane) or host.lane_events.is_lane_blocked(target_lane):
			continue
		vehicle.target_lane = target_lane
		vehicle.lane_change_enabled = true
		if host._can_commit_lane_change_warning(vehicle):
			return
		vehicle.target_lane = vehicle.lane
		vehicle.lane_change_enabled = false
