class_name OverdriveController
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")

enum State { READY, ACTIVE, COOLDOWN }
enum ActivationResult { NONE, ACTIVATED, INSUFFICIENT_FUEL, UNAVAILABLE }

var state: State = State.READY
var active_elapsed := 0.0
var active_remaining := 0.0
var cooldown_remaining := 0.0
var tap_elapsed := INF
var committed_fuel_cost := 0.0
var consumed_fuel := 0.0

func observe_accelerate_press(current_fuel: float, maximum_fuel: float) -> ActivationResult:
	if state != State.READY:
		return ActivationResult.UNAVAILABLE
	if tap_elapsed <= GameConfig.OVERDRIVE_DOUBLE_TAP_WINDOW:
		tap_elapsed = INF
		var required_fuel := maxf(0.0, maximum_fuel) * GameConfig.OVERDRIVE_FUEL_COST_RATIO
		if current_fuel + 0.0001 < required_fuel:
			return ActivationResult.INSUFFICIENT_FUEL
		_start(required_fuel)
		return ActivationResult.ACTIVATED
	tap_elapsed = 0.0
	return ActivationResult.NONE

func tick(delta: float, available_fuel: float) -> float:
	var safe_delta := maxf(0.0, delta)
	if state == State.READY:
		_advance_tap_window(safe_delta)
		return 0.0
	if state == State.COOLDOWN:
		cooldown_remaining = maxf(0.0, cooldown_remaining - safe_delta)
		if is_zero_approx(cooldown_remaining):
			state = State.READY
		return 0.0

	var active_delta := minf(safe_delta, active_remaining)
	active_elapsed += active_delta
	active_remaining = maxf(0.0, active_remaining - active_delta)
	var remaining_cost := maxf(0.0, committed_fuel_cost - consumed_fuel)
	var planned_drain := committed_fuel_cost / GameConfig.OVERDRIVE_DURATION_SECONDS * active_delta
	if is_zero_approx(active_remaining):
		planned_drain = remaining_cost
	var actual_drain := minf(remaining_cost, minf(maxf(0.0, available_fuel), planned_drain))
	consumed_fuel += actual_drain
	if is_zero_approx(active_remaining) or available_fuel <= actual_drain + 0.0001:
		_begin_cooldown()
	return actual_drain

func intensity() -> float:
	if state != State.ACTIVE:
		return 0.0
	var ramp_in := clampf(active_elapsed / GameConfig.OVERDRIVE_RAMP_IN_SECONDS, 0.0, 1.0)
	var ramp_out := clampf(active_remaining / GameConfig.OVERDRIVE_RAMP_OUT_SECONDS, 0.0, 1.0)
	return minf(ramp_in, ramp_out)

func speed_limit_bonus() -> float:
	return GameConfig.OVERDRIVE_SPEED_BONUS * intensity()

func acceleration_bonus() -> float:
	return GameConfig.OVERDRIVE_ACCELERATION_BONUS * intensity()

func is_ready() -> bool:
	return state == State.READY

func is_active() -> bool:
	return state == State.ACTIVE

func is_cooling_down() -> bool:
	return state == State.COOLDOWN

func cancel_tap_sequence() -> void:
	tap_elapsed = INF

func reset() -> void:
	state = State.READY
	active_elapsed = 0.0
	active_remaining = 0.0
	cooldown_remaining = 0.0
	tap_elapsed = INF
	committed_fuel_cost = 0.0
	consumed_fuel = 0.0

func _start(fuel_cost: float) -> void:
	state = State.ACTIVE
	active_elapsed = 0.0
	active_remaining = GameConfig.OVERDRIVE_DURATION_SECONDS
	cooldown_remaining = 0.0
	committed_fuel_cost = maxf(0.0, fuel_cost)
	consumed_fuel = 0.0

func _begin_cooldown() -> void:
	state = State.COOLDOWN
	active_remaining = 0.0
	cooldown_remaining = GameConfig.OVERDRIVE_COOLDOWN_SECONDS
	tap_elapsed = INF

func _advance_tap_window(delta: float) -> void:
	if is_inf(tap_elapsed):
		return
	tap_elapsed += delta
	if tap_elapsed > GameConfig.OVERDRIVE_DOUBLE_TAP_WINDOW:
		tap_elapsed = INF
