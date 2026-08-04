class_name RunState
extends RefCounted

enum Phase {
	TITLE,
	COUNTDOWN,
	RUNNING,
	PAUSED,
	GAME_OVER,
	RUN_CLEAR,
	# Compatibility aliases for the pre-F1 test and gameplay API.
	READY = TITLE,
	ENDED = GAME_OVER,
}

var max_fuel: float
var fuel_drain_per_second: float
var fuel_grace_seconds: float
var phase: Phase = Phase.TITLE
var countdown_remaining: float = 0.0
var elapsed_seconds: float = 0.0
var distance: float = 0.0
var score: int = 0
var overtakes: int = 0
var near_misses: int = 0
var fuel: float
var difficulty_stage: int = 0
var _distance_score_remainder: float = 0.0

func _init(initial_max_fuel: float, drain_per_second: float, grace_seconds: float = 30.0) -> void:
	max_fuel = initial_max_fuel
	fuel_drain_per_second = drain_per_second
	fuel_grace_seconds = grace_seconds
	fuel = max_fuel

func start() -> void:
	if phase == Phase.TITLE:
		phase = Phase.RUNNING

func begin_countdown(seconds: float = 3.0) -> void:
	if phase == Phase.TITLE or phase == Phase.PAUSED or phase == Phase.GAME_OVER or phase == Phase.RUN_CLEAR:
		countdown_remaining = maxf(0.0, seconds)
		phase = Phase.COUNTDOWN
		if is_zero_approx(countdown_remaining):
			phase = Phase.RUNNING

func toggle_pause() -> void:
	if phase == Phase.RUNNING:
		phase = Phase.PAUSED
	elif phase == Phase.PAUSED:
		begin_countdown()

func tick(delta: float, speed: float, maximum_speed: float) -> void:
	if phase == Phase.COUNTDOWN:
		countdown_remaining = maxf(0.0, countdown_remaining - maxf(0.0, delta))
		if is_zero_approx(countdown_remaining):
			phase = Phase.RUNNING
		return
	if phase != Phase.RUNNING:
		return
	elapsed_seconds += delta
	distance += maxf(0.0, speed) * delta * 0.1
	_distance_score_remainder += maxf(0.0, speed) * delta * 0.1
	var gained_score := int(floor(_distance_score_remainder))
	if gained_score > 0:
		score += gained_score
		_distance_score_remainder -= gained_score
	var speed_ratio := clampf(speed / maxf(1.0, maximum_speed), 0.0, 1.0)
	fuel = maxf(0.0, fuel - fuel_drain_per_second * (0.75 + speed_ratio * 0.25) * delta)
	difficulty_stage = _stage_for_elapsed_time(elapsed_seconds)
	if fuel <= 0.0 and elapsed_seconds >= fuel_grace_seconds:
		phase = Phase.GAME_OVER

func add_fuel(amount: float) -> void:
	if phase == Phase.RUNNING:
		fuel = clampf(fuel + maxf(0.0, amount), 0.0, max_fuel)

func award_overtake(points: int) -> void:
	if phase == Phase.RUNNING:
		overtakes += 1
		score += maxi(0, points)

func end() -> void:
	if phase == Phase.RUNNING or phase == Phase.PAUSED or phase == Phase.COUNTDOWN:
		phase = Phase.GAME_OVER

func mark_clear() -> void:
	if phase == Phase.RUNNING or phase == Phase.PAUSED:
		phase = Phase.RUN_CLEAR

func return_to_title() -> void:
	if phase != Phase.RUNNING:
		phase = Phase.TITLE
		countdown_remaining = 0.0

func reset() -> void:
	phase = Phase.TITLE
	countdown_remaining = 0.0
	elapsed_seconds = 0.0
	distance = 0.0
	score = 0
	overtakes = 0
	near_misses = 0
	fuel = max_fuel
	difficulty_stage = 0
	_distance_score_remainder = 0.0

static func _stage_for_elapsed_time(seconds: float) -> int:
	if seconds < 35.0:
		return 0
	if seconds < 75.0:
		return 1
	if seconds < 115.0:
		return 2
	return 3
