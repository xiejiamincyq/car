class_name VehicleIntegrity
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")

enum Condition { HEALTHY, DAMAGED, CRITICAL, FAILED }

const MAX_INTEGRITY := 100.0
const DAMAGED_THRESHOLD := 70.0
const CRITICAL_THRESHOLD := 30.0
const FAILURE_THRESHOLD := 20.0
const DAMAGED_MAX_SPEED_MULTIPLIER := 0.92
const DAMAGED_STEERING_MULTIPLIER := 0.88
const CRITICAL_MAX_SPEED_MULTIPLIER := 0.78
const CRITICAL_STEERING_MULTIPLIER := 0.68

var current := MAX_INTEGRITY

func apply_damage(amount: float) -> Dictionary:
	var condition_before := condition()
	var applied := minf(current, maxf(0.0, amount))
	current = maxf(0.0, current - applied)
	return {
		"applied": applied,
		"condition_before": condition_before,
		"condition_after": condition(),
		"condition_changed": condition_before != condition(),
		"failed": is_failed(),
	}

func condition() -> Condition:
	if current < FAILURE_THRESHOLD:
		return Condition.FAILED
	if current <= CRITICAL_THRESHOLD:
		return Condition.CRITICAL
	if current <= DAMAGED_THRESHOLD:
		return Condition.DAMAGED
	return Condition.HEALTHY

func is_failed() -> bool:
	return current < FAILURE_THRESHOLD

func max_speed_multiplier() -> float:
	match condition():
		Condition.DAMAGED: return DAMAGED_MAX_SPEED_MULTIPLIER
		Condition.CRITICAL, Condition.FAILED: return CRITICAL_MAX_SPEED_MULTIPLIER
		_: return 1.0

func steering_multiplier() -> float:
	match condition():
		Condition.DAMAGED: return DAMAGED_STEERING_MULTIPLIER
		Condition.CRITICAL, Condition.FAILED: return CRITICAL_STEERING_MULTIPLIER
		_: return 1.0

func reset() -> void:
	current = MAX_INTEGRITY

static func damage_for_impact(speed: float, maximum_speed: float) -> float:
	var ratio := clampf(maxf(0.0, speed) / maxf(1.0, maximum_speed), 0.0, 1.0)
	return lerpf(GameConfig.INTEGRITY_NPC_DAMAGE_MIN, GameConfig.INTEGRITY_NPC_DAMAGE_MAX, ratio)
