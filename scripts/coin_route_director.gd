class_name CoinRouteDirector
extends RefCounted

const CoinPickup = preload("res://scripts/coin_pickup.gd")
const Config = preload("res://scripts/game_config.gd")

enum Template { STRAIGHT, GENTLE_MERGE, AVOIDANCE, RISK_LINE, CONSTRUCTION_DIVERSION, LEFT_ARC, RIGHT_ARC, S_CURVE }

const MIN_COIN_COUNT := 6
const MAX_COIN_COUNT := 12
const MIN_SPACING := 55.0
const MAX_SPACING := 75.0
const LANE_HAZARD_RADIUS := 0.55
const PATH_SAMPLE_COUNT := 4
const MAX_GENERATION_ATTEMPTS := 128
const NPC_EXCLUSION_CLEARANCE := 110.0
const FUEL_EXCLUSION_CLEARANCE := 70.0
const CONSTRUCTION_EXCLUSION_CLEARANCE := 130.0

var lane_count: int
var _random := RandomNumberGenerator.new()
var _initial_seed: int
var _next_coin_id := 0
var _next_route_id := 0
var _lane_coin_counts: Array[int] = []
var _curved_route_count := 0
var _entry_range := Vector2.ZERO
var _maximum_slope := 0.0
var _spacing := MIN_SPACING
var _primary_template := Template.STRAIGHT
var _position_attempt := 0

func _init(run_seed: int, lanes: int = 3) -> void:
	lane_count = maxi(1, lanes)
	reset(run_seed)

func reset(run_seed: int = -1) -> void:
	if run_seed >= 0:
		_initial_seed = run_seed
	_random.seed = _initial_seed
	_next_coin_id = 0
	_next_route_id = 0
	_lane_coin_counts.resize(lane_count)
	_lane_coin_counts.fill(0)
	_curved_route_count = 0

func generate_route(
	anchor_y: float,
	player_lane: int,
	npc_zones: Array,
	fuel_zones: Array,
	construction_zones: Array,
	blocked_lanes: Array[int],
	preferred_template: int = -1,
	entry_lane_range: Vector2 = Vector2(-INF, INF),
	maximum_lane_slope: float = INF
) -> Array[CoinPickup]:
	var open_lanes := _open_lanes(blocked_lanes)
	if open_lanes.is_empty():
		return []
	_entry_range = Vector2(maxf(0.0,maxf(float(player_lane)-1.0,entry_lane_range.x)),minf(float(lane_count-1),minf(float(player_lane)+1.0,entry_lane_range.y)))
	if _entry_range.x > _entry_range.y:
		return []
	var width := Config.ROAD_HALF_WIDTH*2.0/Config.ROAD_LANE_COUNT
	_maximum_slope = minf(maxf(0.0,maximum_lane_slope), Config.STEERING_SPEED*0.9/((Config.MAX_SPEED+Config.OVERDRIVE_SPEED_BONUS)*Config.ROAD_SCROLL_MULTIPLIER*width))
	_primary_template = _choose_primary_template(blocked_lanes)
	var zones: Array[Vector3] = []
	_append_zones(zones, npc_zones)
	_append_zones(zones, fuel_zones)
	_append_zones(zones, construction_zones)
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		_position_attempt = attempt
		var template := _template_for_attempt(preferred_template, attempt, blocked_lanes)
		var count := _random.randi_range(MIN_COIN_COUNT, MAX_COIN_COUNT)
		if template not in [Template.STRAIGHT,Template.RISK_LINE]:
			count = MAX_COIN_COUNT
		var spacing := _random.randf_range(MIN_SPACING, MAX_SPACING)
		# A compact final fallback searches every feasible lane instead of hoping
		# random long routes happen to fit a short obstacle-free corridor.
		if preferred_template < 0 and attempt >= 120:
			count = MIN_COIN_COUNT
			spacing = MIN_SPACING
		_spacing = spacing
		var lane_positions := _build_lane_positions(template, count, player_lane, open_lanes, blocked_lanes)
		if lane_positions.size() != count:
			continue
		if lane_positions[0] < entry_lane_range.x or lane_positions[0] > entry_lane_range.y:
			continue
		if not _slope_is_followable(lane_positions, spacing, _maximum_slope):
			continue
		if not _route_path_is_safe(lane_positions, anchor_y, spacing, zones, blocked_lanes):
			continue
		return _make_route(lane_positions, anchor_y, spacing, template)
	return []

static func _slope_is_followable(positions: Array[float], spacing: float, maximum_slope: float) -> bool:
	for index in range(1, positions.size()):
		if absf(positions[index]-positions[index-1]) > spacing*maxf(0.0,maximum_slope):
			return false
	return true

func _template_for_attempt(preferred_template: int, attempt: int, blocked_lanes: Array[int]) -> int:
	if preferred_template >= 0 and preferred_template < Template.size():
		return preferred_template
	if attempt >= 120:
		return Template.STRAIGHT
	# Keep the intended shape while searching positions; only the bounded final
	# quarter may use safe fallbacks. Rejections never count as accepted variety.
	return _primary_template if attempt < 96 else _random.randi_range(0,Template.size()-1)

func _choose_primary_template(blocked: Array[int]) -> int:
	if not blocked.is_empty() and _next_route_id%3==0:return Template.CONSTRUCTION_DIVERSION
	var choices := [Template.LEFT_ARC,Template.RIGHT_ARC,Template.S_CURVE] if _curved_route_count*2<=_next_route_id else [Template.STRAIGHT,Template.GENTLE_MERGE,Template.RISK_LINE]
	return choices[_random.randi_range(0,choices.size()-1)]

func _build_lane_positions(template: int, count: int, player_lane: int, open_lanes: Array[int], blocked_lanes: Array[int]) -> Array[float]:
	match template:
		Template.STRAIGHT:
			return _straight_positions(count, player_lane, open_lanes)
		Template.GENTLE_MERGE:
			return _merge_positions(count, player_lane, open_lanes)
		Template.AVOIDANCE:
			return _avoidance_positions(count, player_lane, open_lanes)
		Template.RISK_LINE:
			return _risk_positions(count, player_lane, open_lanes)
		Template.CONSTRUCTION_DIVERSION:
			return _diversion_positions(count, player_lane, open_lanes, blocked_lanes)
		Template.LEFT_ARC,Template.RIGHT_ARC,Template.S_CURVE:
			return _curve_positions(count,player_lane,open_lanes,template)
	return []

func _straight_positions(count: int, player_lane: int, open_lanes: Array[int]) -> Array[float]:
	var start := _choose_start_position(open_lanes)
	if is_nan(start):
		return []
	return _constant_positions(count,start)

func _merge_positions(count: int, player_lane: int, open_lanes: Array[int]) -> Array[float]:
	var start := _choose_start_position(open_lanes)
	if is_nan(start):return []
	var start_lane := clampi(roundi(start),0,lane_count-1)
	var targets := _adjacent_open_lanes(start_lane, open_lanes)
	if targets.is_empty():
		return _constant_positions(count,start)
	var target_lane: int = targets[_random.randi_range(0, targets.size() - 1)]
	return _lerp_positions(count,start,move_toward(start,float(target_lane),_maximum_slope*_spacing*(count-1)))

func _avoidance_positions(count: int, player_lane: int, open_lanes: Array[int]) -> Array[float]:
	var start := _choose_start_position(open_lanes)
	if is_nan(start):return []
	var start_lane := clampi(roundi(start),0,lane_count-1)
	var targets := _adjacent_open_lanes(start_lane, open_lanes)
	if targets.is_empty():
		return _constant_positions(count,start)
	var target_lane: int = targets[_random.randi_range(0, targets.size() - 1)]
	var sign_value := -1.0 if target_lane < start_lane else 1.0
	return _sin_positions(count,start,sign_value,false)

func _risk_positions(count: int, player_lane: int, open_lanes: Array[int]) -> Array[float]:
	var outer_lanes: Array[int] = []
	for lane in open_lanes:
		if lane == 0 or lane == lane_count - 1:
			if abs(lane - player_lane) <= 1:
				outer_lanes.append(lane)
	if outer_lanes.is_empty():
		return _straight_positions(count, player_lane, open_lanes)
	var start := _choose_start_position(outer_lanes)
	if is_nan(start):
		return _straight_positions(count,player_lane,open_lanes)
	return _constant_positions(count,start)

func _diversion_positions(count: int, player_lane: int, open_lanes: Array[int], blocked_lanes: Array[int]) -> Array[float]:
	if blocked_lanes.is_empty():return _merge_positions(count,player_lane,open_lanes)
	var start := _choose_start_position(open_lanes)
	if is_nan(start):return []
	var start_lane := clampi(roundi(start),0,lane_count-1)
	var target_lane := start_lane
	var greatest_clearance := -1
	var candidates: Array[int] = []
	for lane in open_lanes:
		if abs(lane - start_lane) > 1:
			continue
		var clearance := _distance_from_blocked(lane, blocked_lanes)
		if clearance > greatest_clearance:
			greatest_clearance = clearance
			candidates=[lane]
		elif clearance == greatest_clearance:candidates.append(lane)
	if not candidates.is_empty():target_lane=candidates[_random.randi_range(0,candidates.size()-1)]
	return _lerp_positions(count,start,move_toward(start,float(target_lane),_maximum_slope*_spacing*(count-1)))

func _choose_start_position(open_lanes: Array[int]) -> float:
	var candidates: Array[int] = []
	var feasible: Array[int] = []
	var least := 2147483647
	for lane in open_lanes:
		var low := maxf(_entry_range.x,float(lane)-0.5)
		var high := minf(_entry_range.y,float(lane)+0.5)
		if high < low:continue
		feasible.append(lane)
		if _lane_coin_counts[lane] < least:
			least=_lane_coin_counts[lane]
			candidates=[lane]
		elif _lane_coin_counts[lane]==least:candidates.append(lane)
	if candidates.is_empty():return NAN
	if _position_attempt >= 120:
		var fallback_lane := feasible[(_position_attempt-120)%feasible.size()]
		return clampf(float(fallback_lane),_entry_range.x,_entry_range.y)
	# Alternate balancing with unrestricted safe-position exploration. A less
	# used lane can be hazardous; successful-count balancing is never a quota.
	if _position_attempt % 2 == 1:
		candidates = feasible
	var lane := candidates[_random.randi_range(0,candidates.size()-1)]
	return _random.randf_range(maxf(_entry_range.x,float(lane)-0.5),minf(_entry_range.y,float(lane)+0.5))

func _curve_positions(count: int,_player_lane: int,open_lanes: Array[int],template: int) -> Array[float]:
	var start := _choose_start_position(open_lanes)
	if is_nan(start):return []
	return _sin_positions(count,start,-1.0 if template==Template.LEFT_ARC else 1.0,template==Template.S_CURVE)

func _sin_positions(count: int,start: float,direction: float,s_curve: bool) -> Array[float]:
	var frequency := TAU if s_curve else PI
	var amplitude := minf(_random.randf_range(0.22,0.38),_maximum_slope*_spacing*(count-1)/frequency*0.90)
	var space := minf(start,float(lane_count-1)-start) if s_curve else (start if direction<0 else float(lane_count-1)-start)
	amplitude=minf(amplitude,maxf(0.0,space))
	var positions: Array[float] = []
	for index in count:
		positions.append(start+direction*amplitude*sin(float(index)/maxf(1.0,count-1)*frequency))
	return positions

func _route_path_is_safe(lane_positions: Array[float], anchor_y: float, spacing: float, zones: Array[Vector3], blocked_lanes: Array[int]) -> bool:
	for index in range(lane_positions.size()):
		var coin_y := anchor_y - spacing * float(index)
		if _lane_position_is_blocked(lane_positions[index], blocked_lanes):
			return false
		if overlaps_any_zone(lane_positions[index], coin_y, zones):
			return false
		if index == 0:
			continue
		var previous_y := anchor_y - spacing * float(index - 1)
		for sample_index in range(1, PATH_SAMPLE_COUNT):
			var ratio := float(sample_index) / float(PATH_SAMPLE_COUNT)
			var sample_lane := lerpf(lane_positions[index - 1], lane_positions[index], ratio)
			var sample_y := lerpf(previous_y, coin_y, ratio)
			if _lane_position_is_blocked(sample_lane, blocked_lanes) or overlaps_any_zone(sample_lane, sample_y, zones):
				return false
	return true

func _make_route(lane_positions: Array[float], anchor_y: float, spacing: float, template: int) -> Array[CoinPickup]:
	var route: Array[CoinPickup] = []
	var route_id := _next_route_id
	_next_route_id += 1
	if lane_positions.max()-lane_positions.min()>0.05 and absf(lane_positions[0]-lane_positions[-1])<0.001:
		_curved_route_count+=1
	for index in range(lane_positions.size()):
		_lane_coin_counts[clampi(roundi(lane_positions[index]),0,lane_count-1)]+=1
		route.append(CoinPickup.new(_next_coin_id, lane_positions[index], anchor_y - spacing * float(index), route_id, template))
		_next_coin_id += 1
	return route

func _choose_reachable_lane(player_lane: int, open_lanes: Array[int]) -> int:
	var candidates: Array[int] = []
	for lane in open_lanes:
		if abs(lane - player_lane) <= 1:
			candidates.append(lane)
	if candidates.is_empty():
		return open_lanes[0]
	return candidates[_random.randi_range(0, candidates.size() - 1)]

func _adjacent_open_lanes(lane: int, open_lanes: Array[int]) -> Array[int]:
	var adjacent: Array[int] = []
	for candidate in open_lanes:
		if abs(candidate - lane) == 1:
			adjacent.append(candidate)
	return adjacent

func _open_lanes(blocked_lanes: Array[int]) -> Array[int]:
	var open: Array[int] = []
	for lane in range(lane_count):
		if not blocked_lanes.has(lane):
			open.append(lane)
	return open

func _distance_from_blocked(lane: int, blocked_lanes: Array[int]) -> int:
	if blocked_lanes.is_empty():
		return 0
	var distance := lane_count
	for blocked_lane in blocked_lanes:
		distance = mini(distance, abs(lane - blocked_lane))
	return distance

func _lane_position_is_blocked(lane_position: float, blocked_lanes: Array[int]) -> bool:
	for blocked_lane in blocked_lanes:
		if absf(lane_position - float(blocked_lane)) <= LANE_HAZARD_RADIUS:
			return true
	return false

func _constant_positions(count: int, lane_position: float) -> Array[float]:
	var positions: Array[float] = []
	for _index in range(count):
		positions.append(lane_position)
	return positions

func _lerp_positions(count: int, start: float, target: float) -> Array[float]:
	var positions: Array[float] = []
	for index in range(count):
		var ratio := float(index) / maxf(1.0, float(count - 1))
		positions.append(lerpf(start, target, ratio))
	return positions

func _append_zones(target: Array[Vector3], source: Array) -> void:
	for value in source:
		if value is Vector3:
			target.append(value)

static func overlaps_any_zone(lane_position: float, y: float, zones: Array) -> bool:
	for value in zones:
		if not value is Vector3:
			continue
		var zone: Vector3 = value
		if absf(zone.x - lane_position) <= LANE_HAZARD_RADIUS and absf(zone.y - y) < maxf(0.0, zone.z):
			return true
	return false

static func route_signature(route: Array) -> String:
	var parts := PackedStringArray()
	for coin in route:
		parts.append("%d:%.3f:%.1f" % [coin.template, coin.lane_position, coin.y])
	return "|".join(parts)

static func npc_exclusion_zones(vehicles: Array) -> Array[Vector3]:
	var zones: Array[Vector3] = []
	for vehicle in vehicles:
		var clearance := NPC_EXCLUSION_CLEARANCE + maxf(0.0, float(vehicle.half_length))
		zones.append(Vector3(float(vehicle.lane), float(vehicle.y), clearance))
		if vehicle.lane_change_enabled and vehicle.target_lane != vehicle.lane:
			zones.append(Vector3(float(vehicle.target_lane), float(vehicle.y), clearance))
	return zones

static func fuel_exclusion_zones(pickups: Array) -> Array[Vector3]:
	var zones: Array[Vector3] = []
	for pickup in pickups:
		zones.append(Vector3(float(pickup.lane), float(pickup.y), FUEL_EXCLUSION_CLEARANCE))
	return zones

static func construction_exclusion_zones(core_markers: Array) -> Array[Vector3]:
	var zones: Array[Vector3] = []
	for marker_value in core_markers:
		if not marker_value is Vector2:
			continue
		var marker: Vector2 = marker_value
		zones.append(Vector3(marker.x - 0.5, marker.y, CONSTRUCTION_EXCLUSION_CLEARANCE))
	return zones

static func traffic_spawn_exclusion_zones(coins: Array, lanes: int = 3) -> Array[Vector2]:
	var zones: Array[Vector2] = []
	for coin in coins:
		if coin.collected:
			continue
		for lane in range(maxi(1, lanes)):
			if absf(float(lane) - coin.lane_position) <= LANE_HAZARD_RADIUS:
				zones.append(Vector2(float(lane), coin.y))
	return zones
