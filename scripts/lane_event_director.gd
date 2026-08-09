class_name LaneEventDirector
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")

enum State { IDLE, WARNING, CLOSED }

var state: State = State.IDLE
var state_remaining := 0.0
var lane := -1
var enabled := true
var lane_count := 3
var _random := RandomNumberGenerator.new()
var _initial_seed: int
var _cooldown_remaining := 0.0
var _history := PackedStringArray()
var interval_multiplier := 1.0

func _init(seed: int, lanes: int = 3, events_enabled: bool = true) -> void:
	_initial_seed = seed
	lane_count = maxi(1, lanes)
	enabled = events_enabled
	reset(seed)

func tick(delta: float, stage: int, player_lane: int) -> Dictionary:
	var event := {"began_warning": false, "began_closure": false, "ended": false}
	if not enabled or stage < 2:
		return event
	var safe_delta := maxf(0.0, delta)
	match state:
		State.IDLE:
			_cooldown_remaining -= safe_delta
			if _cooldown_remaining <= 0.0:
				begin_warning(_choose_lane_away_from(player_lane))
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
				state_remaining = 0.0
				_cooldown_remaining = _next_cooldown()
				event.ended = true
	return event

func begin_warning(target_lane: int) -> void:
	lane = clampi(target_lane, 0, lane_count - 1)
	state = State.WARNING
	state_remaining = GameConfig.LANE_EVENT_WARNING_SECONDS
	_history.append("warning:%d" % lane)

func blocked_lane() -> int:
	return lane if state == State.WARNING or state == State.CLOSED else -1

func constrain_lateral_position(position: float, player_half_width: float, road_half_width: float) -> float:
	var road_limit := maxf(0.0, road_half_width)
	var car_half_width := clampf(player_half_width, 0.0, road_limit)
	var minimum_center := -road_limit + car_half_width
	var maximum_center := road_limit - car_half_width
	var safe_position := clampf(position, minimum_center, maximum_center)
	if state != State.CLOSED or lane < 0 or lane >= lane_count:
		return safe_position
	var lane_width := road_limit * 2.0 / lane_count
	var lane_left := -road_limit + lane_width * lane
	var lane_right := lane_left + lane_width
	var left_limit := lane_left - car_half_width
	var right_limit := lane_right + car_half_width
	if safe_position <= left_limit or safe_position >= right_limit:
		return safe_position
	var can_exit_left := left_limit >= minimum_center
	var can_exit_right := right_limit <= maximum_center
	if can_exit_left and can_exit_right:
		return left_limit if absf(safe_position - left_limit) <= absf(safe_position - right_limit) else right_limit
	if can_exit_left:
		return left_limit
	return right_limit if can_exit_right else safe_position

func event_history() -> String:
	return "|".join(_history)

func configure_interval_multiplier(multiplier: float) -> void:
	interval_multiplier = maxf(0.1, multiplier)
	if state == State.IDLE:
		_cooldown_remaining = _next_cooldown()

func reset(seed: int = -1) -> void:
	if seed >= 0:
		_initial_seed = seed
	_random.seed = _initial_seed
	state = State.IDLE
	state_remaining = 0.0
	lane = -1
	_history.clear()
	_cooldown_remaining = _next_cooldown()

func _choose_lane_away_from(player_lane: int) -> int:
	var candidates: Array[int] = []
	for candidate in range(lane_count):
		if candidate != player_lane:
			candidates.append(candidate)
	if candidates.is_empty():
		return clampi(player_lane, 0, lane_count - 1)
	return candidates[_random.randi_range(0, candidates.size() - 1)]

func _next_cooldown() -> float:
	return _random.randf_range(GameConfig.LANE_EVENT_MIN_INTERVAL_SECONDS, GameConfig.LANE_EVENT_MAX_INTERVAL_SECONDS) * interval_multiplier
