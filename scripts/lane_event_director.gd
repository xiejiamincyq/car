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

func _init(seed: int, lanes: int = 3, events_enabled: bool = true) -> void:
	_initial_seed = seed
	lane_count = maxi(1, lanes)
	enabled = events_enabled
	reset(seed)

func tick(delta: float, stage: int, player_lane: int) -> Dictionary:
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
				_begin_scheduled_warning(stage, player_lane)
				event.began_warning = true
		State.WARNING:
			state_remaining -= safe_delta
			if state_remaining <= 0.0:
				state = State.CLOSED
				state_remaining = GameConfig.LANE_EVENT_CLOSED_SECONDS
				_history.append("closed:%d" % lane)
				event.began_closure = true
		State.CLOSED:
			state_remaining -= safe_delta
			if state_remaining <= 0.0:
				_history.append("ended:%d" % lane)
				state = State.IDLE
				lane = -1
				_closed_lanes.clear()
				_consumed_cones.clear()
				state_remaining = 0.0
				_cooldown_remaining = _next_cooldown()
				event.ended = true
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
	if state == State.WARNING:
		var progress := clampf(1.0 - state_remaining / maxf(0.01, _warning_duration), 0.0, 1.0)
		var tip_y := lerpf(-20.0, viewport_height * 0.82, progress)
		var closed_edge := 0.0 if _closed_lanes.has(0) else float(lane_count)
		for index in range(GameConfig.LANE_EVENT_TAPER_CONE_COUNT):
			if _consumed_cones.has(index):
				continue
			var ratio := float(index) / maxf(1.0, float(GameConfig.LANE_EVENT_TAPER_CONE_COUNT - 1))
			var marker_y := tip_y - GameConfig.LANE_EVENT_TAPER_CONE_SPACING * index
			if marker_y >= -60.0 and marker_y <= viewport_height + 60.0:
				markers.append({"id": index, "lane_position": lerpf(boundary, closed_edge, ratio), "y": marker_y})
		return markers
	var core_y := _core_y(viewport_height)
	for index in range(GameConfig.LANE_EVENT_TAPER_CONE_COUNT):
		var marker_id := 100 + index
		if _consumed_cones.has(marker_id):
			continue
		var centered_index := float(index) - float(GameConfig.LANE_EVENT_TAPER_CONE_COUNT - 1) * 0.5
		var marker_y := core_y + centered_index * GameConfig.LANE_EVENT_TAPER_CONE_SPACING
		if marker_y >= -60.0 and marker_y <= viewport_height + 60.0:
			markers.append({"id": marker_id, "lane_position": boundary, "y": marker_y})
	return markers

func core_markers(viewport_height: float) -> Array[Vector2]:
	var markers: Array[Vector2] = []
	if state != State.CLOSED:
		return markers
	var marker_y := _core_y(viewport_height)
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
	_cooldown_remaining = _next_cooldown()

func _choose_lane_away_from(player_lane: int) -> int:
	var candidates: Array[int] = [0]
	if lane_count > 1:
		candidates.append(lane_count - 1)
	candidates.erase(player_lane)
	if candidates.is_empty():
		return clampi(player_lane, 0, lane_count - 1)
	return candidates[_random.randi_range(0, candidates.size() - 1)]

func _begin_scheduled_warning(stage: int, player_lane: int) -> void:
	var may_close_two := stage >= 3 and lane_count >= 3 and player_lane != 1 and double_lane_events_started == 0 and _random.randf() < double_lane_probability
	if may_close_two:
		var double_lanes: Array[int] = []
		double_lanes.assign([1, 2] if player_lane == 0 else [0, 1])
		begin_warning_lanes(double_lanes)
		return
	begin_warning(_choose_lane_away_from(player_lane))

func _lane_signature() -> String:
	var parts := PackedStringArray()
	for closed_lane in _closed_lanes:
		parts.append(str(closed_lane))
	return ",".join(parts)

func _open_lane_boundary() -> float:
	if _closed_lanes.has(0):
		return float(_closed_lanes.size())
	return float(lane_count - _closed_lanes.size())

func _core_y(viewport_height: float) -> float:
	var progress := clampf(1.0 - state_remaining / maxf(0.01, GameConfig.LANE_EVENT_CLOSED_SECONDS), 0.0, 1.0)
	return lerpf(-GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN, viewport_height + GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN, progress)

func _next_cooldown() -> float:
	return _random.randf_range(GameConfig.LANE_EVENT_MIN_INTERVAL_SECONDS, GameConfig.LANE_EVENT_MAX_INTERVAL_SECONDS) * interval_multiplier
