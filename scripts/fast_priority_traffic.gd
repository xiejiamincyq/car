extends RefCounted
## One overtaker owns the corridor; existing traffic yields through normal physics.
const Vehicle = preload("res://scripts/traffic_vehicle.gd")
const Safety = preload("res://scripts/traffic_safety_policy.gd")
var _owner: Vehicle = null
var _generation := -1
var _yielding: Vehicle = null
var _partner: Vehicle = null
var _yield_generation := -1
var _partner_generation := -1

func reset() -> void:
	_owner = null
	_generation = -1
	_clear_stagger()

func refresh(vehicles: Array) -> void:
	if _owner != null and (_owner.motion_generation != _generation or not vehicles.has(_owner) or _owner.kind != Vehicle.FAST_OVERTAKE_KIND or _owner.y + _owner.half_length < 0.0):
		reset()
	if _owner != null:
		return
	for vehicle in vehicles:
		if vehicle.kind == Vehicle.FAST_OVERTAKE_KIND and vehicle.y + vehicle.half_length >= 0.0 and (_owner == null or vehicle.y < _owner.y):
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
	if overtaker == _owner and leader != null and leader.lane == overtaker.lane and _yielding != null and (leader == _partner or leader == _yielding):
		# The neighboring car is making a merge slot for this leader. A red
		# reservation in that same slot would block the planned cooperative yield.
		var alternative_lane: int = host._best_fast_route_lane(overtaker)
		var slot_lane: int = _yielding.lane if leader == _partner else _partner.lane
		if alternative_lane < 0 or alternative_lane == slot_lane:
			return true
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

func _clear_stagger() -> void:
	_yielding = null
	_partner = null
	_yield_generation = -1
	_partner_generation = -1

func coordinate_stagger(host) -> void:
	if _owner == null:
		_clear_stagger()
		return
	if _yielding != null:
		if not host.vehicles.has(_yielding) or not host.vehicles.has(_partner) \
			or _yielding.motion_generation != _yield_generation or _partner.motion_generation != _partner_generation \
			or _owner.y + _owner.half_length < minf(_yielding.y - _yielding.half_length, _partner.y - _partner.half_length):
			_clear_stagger()
		else:
			return
	# A clear third lane is not a passing route when the other two lanes form
	# a parallel wall. Keep one stable yielding actor until the pass is complete.
	var corridor := reserved_lanes()
	for first in host.vehicles:
		if first == _owner or first.kind == Vehicle.FAST_OVERTAKE_KIND or first.change_started or first.y >= _owner.y:
			continue
		if _owner.y - first.y > host._fast_planning_distance(_owner):
			continue
		for second in host.vehicles:
			if second == first or second == _owner or second.kind == Vehicle.FAST_OVERTAKE_KIND or second.change_started or second.y >= _owner.y or first.lane == second.lane:
				continue
			var clearance: float = host.minimum_lane_gap + first.half_length + second.half_length + 32.0
			if absf(first.y - second.y) >= clearance:
				continue
			# A leader can only yield into an adjacent lane. Do not create a slot
			# two lanes away and then hold the red car waiting for an impossible turn.
			if corridor.has(first.lane) and corridor.has(second.lane):
				continue
			if (corridor.has(first.lane) or corridor.has(second.lane)) and abs(first.lane - second.lane) > 1:
				continue
			_yielding = second if corridor.has(first.lane) else first
			_partner = first if _yielding == second else second
			if not is_equal_approx(first.y, second.y):
				# Slow the rear member, never make the front member fall backwards
				# across its partner: that creates a new wall and mutual braking.
				_yielding = first if first.y > second.y else second
				_partner = second if _yielding == first else first
			elif not corridor.has(first.lane) and not corridor.has(second.lane):
				if abs(second.lane - host._player_lane) > abs(first.lane - host._player_lane) or (abs(second.lane - host._player_lane) == abs(first.lane - host._player_lane) and second.y > first.y):
					_yielding = second
					_partner = first
			_yield_generation = _yielding.motion_generation
			_partner_generation = _partner.motion_generation
			return

func cooperative_target_speed(host, vehicle: Vehicle) -> float:
	if vehicle == _partner and _yielding != null and _owner != null \
		and reserved_lanes().has(vehicle.lane) and not vehicle.change_started:
		return _front_slot_target(host, vehicle)
	if vehicle != _yielding or _partner == null:
		return INF
	var clearance: float = host.minimum_lane_gap + vehicle.half_length + _partner.half_length + 32.0
	var missing_gap: float = maxf(0.0, clearance - (vehicle.y - _partner.y))
	# A transient target only: assigned cruise speed remains fixed. Actual speed
	# is still resolved through the owner's normal finite brake/acceleration step.
	return maxf(0.0, _partner.actual_world_speed - missing_gap / host.GameConfig.ROAD_SCROLL_MULTIPLIER)

func _front_slot_target(host, leader: Vehicle) -> float:
	var target := INF
	# A rear slot alone is insufficient if a third car still blocks its front.
	# Fit the leader behind that car; the rear yielding lease continues to keep
	# its own slot open. Every resulting speed still goes through finite physics.
	for other in host.vehicles:
		if other == _owner or other == leader or other == _yielding or other.y >= leader.y:
			continue
		var clearance := 0.0
		if Safety.reserved_lanes(other).has(_yielding.lane):
			clearance = host.minimum_lane_gap + leader.half_length + other.half_length + 4.0
		else:
			var occupied: Array[int] = [leader.lane,_yielding.lane]
			for lane in Safety.reserved_lanes(other):
				if not occupied.has(lane): occupied.append(lane)
			if occupied.size() >= host.lane_count:
				# A turn reserves two lanes. The third-lane car must be staggered
				# too, otherwise an otherwise valid slot still makes a complete wall.
				clearance = maxf(Safety.WALL_LONGITUDINAL_CLEARANCE,host.collision_distance_for(leader) + host.collision_distance_for(other)) + 4.0
		if is_zero_approx(clearance):
			continue
		var missing_gap: float = maxf(0.0, clearance - (leader.y - other.y))
		if missing_gap > 0.0:
			target = minf(target,maxf(0.0,other.actual_world_speed - missing_gap / (0.5 * host.GameConfig.ROAD_SCROLL_MULTIPLIER)))
	return target

func prepare_normal(host, vehicle: Vehicle) -> void:
	if _owner == null or vehicle.change_started:
		return
	var corridor := reserved_lanes()
	if vehicle.lane_change_enabled and corridor.has(vehicle.target_lane) and vehicle.target_lane != vehicle.lane:
		host._cancel_planned_lane_change(vehicle)
	if not corridor.has(vehicle.lane) or vehicle.y >= _owner.y or _owner.y - vehicle.y > host._fast_planning_distance(_owner) * 2.0:
		return
	if vehicle.lane_change_enabled or vehicle.lane_change_cooldown > 0.0 or not host._is_lane_change_visible(vehicle):
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
