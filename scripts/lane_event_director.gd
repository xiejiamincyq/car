class_name LaneEventDirector
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")

enum State { IDLE, WARNING, CLOSED }

var state: State = State.IDLE
var state_remaining := 0.0
var lane := -1
var _closed_lanes: Array[int] = []
var enabled := true
var lane_count := 3
var _random := RandomNumberGenerator.new()
var _initial_seed: int
var _cooldown_remaining := 0.0
var _history := PackedStringArray()
var interval_multiplier := 1.0
var _consumed_cones: Dictionary = {}
var double_lane_probability := 0.0
var events_started_count := 0
var double_lane_events_started := 0
var event_limit := 2
var _warning_duration := GameConfig.LANE_EVENT_WARNING_SECONDS
var _travel_distance := 0.0
var _viewport_height := 720.0
var _guidance_reserved_lanes: Array[int] = []

func _init(seed: int, lanes: int = 3, events_enabled: bool = true) -> void:
	_initial_seed = seed
	lane_count = maxi(1, lanes)
	enabled = events_enabled
	reset(seed)

func tick(delta: float, stage: int, player_lane: int, player_speed: float = 0.0) -> Dictionary:
	var event := {"began_warning": false, "began_closure": false, "ended": false}
	if not enabled or stage < 1:
		return event
	var safe_delta := maxf(0.0, delta)
	match state:
		State.IDLE:
			if events_started_count >= event_limit:
				return event
			_cooldown_remaining -= safe_delta
			if _cooldown_remaining <= 0.0:
				event.began_warning = _begin_scheduled_warning(stage, player_lane)
		State.WARNING:
			_advance_road_distance(safe_delta, player_speed)
			if _travel_distance >= _warning_distance():
				state = State.CLOSED
				_history.append("closed:%d" % lane)
				event.began_closure = true
			_refresh_state_remaining()
		State.CLOSED:
			_advance_road_distance(safe_delta, player_speed)
			if _event_tail_y() > _viewport_height + GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN:
				_history.append("ended:%d" % lane)
				state = State.IDLE
				lane = -1
				_closed_lanes.clear()
				_consumed_cones.clear()
				state_remaining = 0.0
				_cooldown_remaining = _next_cooldown()
				event.ended = true
			else:
				_refresh_state_remaining()
	return event

func begin_warning(target_lane: int) -> void:
	begin_warning_lanes([clampi(target_lane, 0, lane_count - 1)])

func begin_warning_lanes(target_lanes: Array[int]) -> void:
	_closed_lanes.clear()
	for target_lane in target_lanes:
		var safe_lane := clampi(target_lane, 0, lane_count - 1)
		if not _closed_lanes.has(safe_lane):
			_closed_lanes.append(safe_lane)
	_closed_lanes.sort()
	if _closed_lanes.is_empty():
		_closed_lanes.append(0)
	lane = _closed_lanes[0]
	_consumed_cones.clear()
	_warning_duration = GameConfig.LANE_EVENT_DOUBLE_WARNING_SECONDS if _closed_lanes.size() > 1 else GameConfig.LANE_EVENT_WARNING_SECONDS
	_travel_distance = 0.0
	state = State.WARNING
	state_remaining = _warning_duration
	events_started_count += 1
	if _closed_lanes.size() > 1:
		double_lane_events_started += 1
	_history.append("warning:%s" % _lane_signature())

func blocked_lane() -> int:
	return lane if state == State.WARNING or state == State.CLOSED else -1

func closed_lanes() -> Array[int]:
	if state != State.WARNING and state != State.CLOSED:
		return []
	return _closed_lanes.duplicate()

func is_lane_blocked(target_lane: int) -> bool:
	return (state == State.WARNING or state == State.CLOSED) and _closed_lanes.has(target_lane)

func open_lanes() -> Array[int]:
	var open: Array[int] = []
	for candidate in range(lane_count):
		if not is_lane_blocked(candidate):
			open.append(candidate)
	return open

func cone_markers(viewport_height: float) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if _closed_lanes.is_empty() or (state != State.WARNING and state != State.CLOSED):
		return markers
	var boundary := _open_lane_boundary()
	var closed_edge := 0.0 if _closed_lanes.has(0) else float(lane_count)
	for index in range(GameConfig.LANE_EVENT_TAPER_CONE_COUNT):
		if _consumed_cones.has(index):
			continue
		var ratio := float(index) / maxf(1.0, float(GameConfig.LANE_EVENT_TAPER_CONE_COUNT - 1))
		var marker_y := _event_origin_y() - GameConfig.LANE_EVENT_TAPER_CONE_SPACING * index
		if marker_y >= -60.0 and marker_y <= viewport_height + 60.0:
			markers.append({"id": index, "lane_position": lerpf(closed_edge, boundary, ratio), "y": marker_y})
	for index in range(1, GameConfig.LANE_EVENT_STRAIGHT_CONE_COUNT + 1):
		var marker_id := 100 + index
		if _consumed_cones.has(marker_id):
			continue
		var marker_y := _taper_end_y() - GameConfig.LANE_EVENT_TAPER_CONE_SPACING * index
		if marker_y >= -60.0 and marker_y <= viewport_height + 60.0:
			markers.append({"id": marker_id, "lane_position": boundary, "y": marker_y})
	return markers

func core_markers(viewport_height: float) -> Array[Vector2]:
	var markers: Array[Vector2] = []
	if state != State.WARNING and state != State.CLOSED:
		return markers
	var marker_y := _core_y()
	if marker_y < -GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN or marker_y > viewport_height + GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN:
		return markers
	for closed_lane in _closed_lanes:
		markers.append(Vector2(float(closed_lane) + 0.5, marker_y))
	return markers

func lanes_blocked_near(y: float, clearance: float, viewport_height: float) -> Array[int]:
	var blocked: Array[int] = []
	for marker in core_markers(viewport_height):
		if absf(marker.y - y) < maxf(0.0, clearance) + 62.0:
			var marker_lane := clampi(int(floor(marker.x)), 0, lane_count - 1)
			if not blocked.has(marker_lane):
				blocked.append(marker_lane)
	blocked.sort()
	return blocked

func navigation_blocked_lanes(y: float, clearance: float, viewport_height: float) -> Array[int]:
	if state == State.WARNING:
		return closed_lanes()
	if state == State.CLOSED:
		var cores := core_markers(viewport_height)
		if not cores.is_empty() and cores[0].y <= y + maxf(0.0, clearance) + 62.0:
			return closed_lanes()
	return []

func consume_cone(cone_id: int) -> bool:
	if _consumed_cones.has(cone_id):
		return false
	_consumed_cones[cone_id] = true
	return true

func cancel_warning() -> void:
	if state != State.WARNING:
		return
	_history.append("cancelled:%s" % _lane_signature())
	events_started_count = maxi(0, events_started_count - 1)
	if _closed_lanes.size() > 1:
		double_lane_events_started = maxi(0, double_lane_events_started - 1)
	state = State.IDLE
	lane = -1
	_closed_lanes.clear()
	_consumed_cones.clear()
	state_remaining = 0.0
	_cooldown_remaining = _next_cooldown()

func constrain_lateral_position(position: float, player_half_width: float, road_half_width: float) -> float:
	var road_limit := maxf(0.0, road_half_width)
	var car_half_width := clampf(player_half_width, 0.0, road_limit)
	var minimum_center := -road_limit + car_half_width
	var maximum_center := road_limit - car_half_width
	return clampf(position, minimum_center, maximum_center)

func event_history() -> String:
	return "|".join(_history)

func configure_interval_multiplier(multiplier: float) -> void:
	interval_multiplier = maxf(0.1, multiplier)
	if state == State.IDLE:
		_cooldown_remaining = _next_cooldown()

func configure_double_lane_probability(probability: float) -> void:
	double_lane_probability = clampf(probability, 0.0, 1.0)

func set_guidance_reserved_lanes(lanes: Array[int]) -> void:
	_guidance_reserved_lanes.clear()
	for lane_value in lanes:
		var reserved_lane := clampi(lane_value, 0, lane_count - 1)
		if not _guidance_reserved_lanes.has(reserved_lane):
			_guidance_reserved_lanes.append(reserved_lane)
	_guidance_reserved_lanes.sort()

func set_viewport_height(viewport_height: float) -> void:
	_viewport_height = maxf(1.0, viewport_height)

func reset(seed: int = -1) -> void:
	if seed >= 0:
		_initial_seed = seed
	_random.seed = _initial_seed
	state = State.IDLE
	state_remaining = 0.0
	lane = -1
	_closed_lanes.clear()
	_consumed_cones.clear()
	_history.clear()
	events_started_count = 0
	double_lane_events_started = 0
	event_limit = _random.randi_range(2, 4)
	_warning_duration = GameConfig.LANE_EVENT_WARNING_SECONDS
	_travel_distance = 0.0
	_cooldown_remaining = _next_cooldown()
	_guidance_reserved_lanes.clear()

func _choose_lane_away_from(player_lane: int) -> int:
	var candidates: Array[int] = [0]
	if lane_count > 1:
		candidates.append(lane_count - 1)
	candidates.erase(player_lane)
	for reserved_lane in _guidance_reserved_lanes:
		candidates.erase(reserved_lane)
	if candidates.is_empty():
		return -1
	return candidates[_random.randi_range(0, candidates.size() - 1)]

func _begin_scheduled_warning(stage: int, player_lane: int) -> bool:
	var may_close_two := stage >= 3 and lane_count >= 3 and player_lane != 1 and double_lane_events_started == 0 and _random.randf() < double_lane_probability
	if may_close_two:
		var double_lanes: Array[int] = []
		double_lanes.assign([1, 2] if player_lane == 0 else [0, 1])
		var conflicts_with_guidance := false
		for double_lane in double_lanes:
			if _guidance_reserved_lanes.has(double_lane):
				conflicts_with_guidance = true
		if not conflicts_with_guidance:
			begin_warning_lanes(double_lanes)
			return true
	var target_lane := _choose_lane_away_from(player_lane)
	if target_lane < 0:
		_cooldown_remaining = maxf(0.5, _next_cooldown() * 0.25)
		return false
	begin_warning(target_lane)
	return true

func _lane_signature() -> String:
	var parts := PackedStringArray()
	for closed_lane in _closed_lanes:
		parts.append(str(closed_lane))
	return ",".join(parts)

func _open_lane_boundary() -> float:
	if _closed_lanes.has(0):
		return float(_closed_lanes.size())
	return float(lane_count - _closed_lanes.size())

func _advance_road_distance(delta: float, player_speed: float) -> void:
	_travel_distance += maxf(0.0, player_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER * delta

func _warning_distance() -> float:
	return _warning_duration * GameConfig.START_SPEED * GameConfig.ROAD_SCROLL_MULTIPLIER

func _event_origin_y() -> float:
	var extra_warning_distance := maxf(0.0, _warning_duration - GameConfig.LANE_EVENT_WARNING_SECONDS) * GameConfig.START_SPEED * GameConfig.ROAD_SCROLL_MULTIPLIER
	return -GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN - extra_warning_distance + _travel_distance

func _taper_end_y() -> float:
	return _event_origin_y() - GameConfig.LANE_EVENT_TAPER_CONE_SPACING * float(GameConfig.LANE_EVENT_TAPER_CONE_COUNT - 1)

func _core_y() -> float:
	return _taper_end_y() - GameConfig.LANE_EVENT_CORE_GAP

func _event_tail_y() -> float:
	return _taper_end_y() - GameConfig.LANE_EVENT_TAPER_CONE_SPACING * GameConfig.LANE_EVENT_STRAIGHT_CONE_COUNT

func _refresh_state_remaining() -> void:
	var reference_scroll_speed := GameConfig.START_SPEED * GameConfig.ROAD_SCROLL_MULTIPLIER
	if state == State.WARNING:
		state_remaining = maxf(0.0, (_warning_distance() - _travel_distance) / reference_scroll_speed)
	elif state == State.CLOSED:
		state_remaining = maxf(0.0, (_viewport_height + GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN - _event_tail_y()) / reference_scroll_speed)

func _next_cooldown() -> float:
	return _random.randf_range(GameConfig.LANE_EVENT_MIN_INTERVAL_SECONDS, GameConfig.LANE_EVENT_MAX_INTERVAL_SECONDS) * interval_multiplier
