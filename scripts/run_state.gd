class_name RunState
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")
const ComboTracker = preload("res://scripts/combo_tracker.gd")
const RaceProgression = preload("res://scripts/race_progression.gd")

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
var base_fuel_drain_per_second: float
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
var combo: ComboTracker
var progression: RaceProgression
var last_checkpoints_crossed: int = 0

func _init(initial_max_fuel: float, drain_per_second: float, grace_seconds: float = 30.0) -> void:
	max_fuel = initial_max_fuel
	base_fuel_drain_per_second = drain_per_second
	fuel_drain_per_second = base_fuel_drain_per_second
	fuel_grace_seconds = grace_seconds
	fuel = max_fuel
	combo = ComboTracker.new(GameConfig.COMBO_WINDOW_SECONDS, GameConfig.COMBO_MAX_MULTIPLIER, GameConfig.COMBO_EVENTS_PER_MULTIPLIER)
	progression = RaceProgression.new(GameConfig.RACE_CHECKPOINT_DISTANCES, GameConfig.RACE_FINISH_DISTANCE)

func configure_difficulty(profile: Dictionary) -> void:
	fuel_drain_per_second = base_fuel_drain_per_second * maxf(0.0, float(profile.fuel_drain_multiplier))
	combo.window_seconds = maxf(0.1, GameConfig.COMBO_WINDOW_SECONDS * float(profile.combo_window_multiplier))

func configure_track(profile: Dictionary) -> void:
	var checkpoints: Array = profile.get("checkpoint_distances", GameConfig.RACE_CHECKPOINT_DISTANCES)
	var finish := float(profile.get("finish_distance", GameConfig.RACE_FINISH_DISTANCE))
	progression = RaceProgression.new(checkpoints, finish)

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

func pause_for_focus_loss() -> void:
	if phase == Phase.RUNNING or phase == Phase.COUNTDOWN:
		phase = Phase.PAUSED
		countdown_remaining = 0.0

func tick(delta: float, speed: float, maximum_speed: float, forward_acceleration: float = 0.0) -> void:
	if phase == Phase.COUNTDOWN:
		countdown_remaining = maxf(0.0, countdown_remaining - maxf(0.0, delta))
		if is_zero_approx(countdown_remaining):
			phase = Phase.RUNNING
		return
	if phase != Phase.RUNNING:
		return
	combo.tick(delta)
	elapsed_seconds += delta
	distance += maxf(0.0, speed) * delta * 0.1
	_distance_score_remainder += maxf(0.0, speed) * delta * 0.1
	var gained_score := int(floor(_distance_score_remainder))
	if gained_score > 0:
		score += gained_score
		_distance_score_remainder -= gained_score
	fuel = maxf(0.0, fuel - fuel_drain_per_second * fuel_load(speed, maximum_speed, forward_acceleration) * delta)
	var progress_event := progression.observe(distance)
	difficulty_stage = progress_event.stage
	last_checkpoints_crossed = progress_event.checkpoints_crossed
	if last_checkpoints_crossed > 0:
		fuel = clampf(fuel + GameConfig.CHECKPOINT_FUEL_REWARD * last_checkpoints_crossed, 0.0, max_fuel)
	if progress_event.cleared:
		phase = Phase.RUN_CLEAR
		return
	if fuel <= 0.0 and elapsed_seconds >= fuel_grace_seconds:
		phase = Phase.GAME_OVER

func add_fuel(amount: float) -> void:
	if phase == Phase.RUNNING:
		fuel = clampf(fuel + maxf(0.0, amount), 0.0, max_fuel)

func award_overtake(points: int) -> void:
	award_pass(points, false)

func award_pass(points: int, was_near_miss: bool) -> void:
	if phase == Phase.RUNNING:
		overtakes += 1
		near_misses += 1 if was_near_miss else 0
		score += combo.award(points)

func register_near_miss() -> void:
	if phase == Phase.RUNNING:
		near_misses += 1

func break_combo() -> void:
	combo.clear()

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
	combo.clear()
	progression.reset()
	last_checkpoints_crossed = 0

static func _stage_for_elapsed_time(seconds: float) -> int:
	if seconds < 35.0:
		return 0
	if seconds < 75.0:
		return 1
	if seconds < 115.0:
		return 2
	return 3

static func resistance_fuel_load(speed: float, maximum_speed: float) -> float:
	var speed_ratio := clampf(maxf(0.0, speed) / maxf(1.0, maximum_speed), 0.0, 1.0)
	var rolling_load := GameConfig.FUEL_ROLLING_RESISTANCE_LOAD * clampf(
		speed_ratio / GameConfig.FUEL_ROLLING_RESISTANCE_FULL_SPEED_RATIO,
		0.0,
		1.0
	)
	var aerodynamic_load := GameConfig.FUEL_AERODYNAMIC_RESISTANCE_LOAD * speed_ratio * speed_ratio
	return rolling_load + aerodynamic_load

static func acceleration_fuel_load(forward_acceleration: float) -> float:
	var acceleration_ratio := maxf(0.0, forward_acceleration) / GameConfig.ACCELERATION
	return GameConfig.FUEL_ACCELERATION_LOAD * minf(acceleration_ratio, 1.25)

static func fuel_load(speed: float, maximum_speed: float, forward_acceleration: float) -> float:
	return resistance_fuel_load(speed, maximum_speed) + acceleration_fuel_load(forward_acceleration)
