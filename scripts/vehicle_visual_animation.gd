class_name VehicleVisualAnimation
extends RefCounted

const COLLISION_DURATION := 0.55
const MAX_COLLISION_ROTATION := 0.18
const FINISH_EMBLEM_DURATION := 0.75

static func acceleration_flame_length(time_seconds: float, throttle: float) -> float:
	if throttle <= 0.0:
		return 0.0
	var pulse := 0.5 + 0.5 * sin(time_seconds * 34.0)
	return lerpf(8.0, 24.0, clampf(throttle, 0.0, 1.0) * (0.65 + pulse * 0.35))

static func collision_rotation(remaining: float, direction: float) -> float:
	if remaining <= 0.0:
		return 0.0
	var progress := 1.0 - clampf(remaining / COLLISION_DURATION, 0.0, 1.0)
	return sin(progress * TAU * 2.5) * MAX_COLLISION_ROTATION * (1.0 - progress) * signf(direction)

static func collision_scale(remaining: float) -> Vector2:
	if remaining <= 0.0:
		return Vector2.ONE
	var progress := 1.0 - clampf(remaining / COLLISION_DURATION, 0.0, 1.0)
	var impulse := (1.0 - progress) * (0.75 + 0.25 * cos(progress * TAU * 2.0))
	return Vector2(1.0 + 0.12 * impulse, 1.0 - 0.10 * impulse)

static func collision_ring_alpha(remaining: float) -> float:
	if remaining <= 0.0:
		return 0.0
	return clampf(remaining / COLLISION_DURATION, 0.0, 1.0) * 0.7

static func brake_light_alpha(time_seconds: float, brake_input: float) -> float:
	if brake_input <= 0.0:
		return 0.0
	var pulse := 0.82 + sin(time_seconds * 28.0) * 0.18
	return clampf(brake_input, 0.0, 1.0) * pulse

static func brake_streak_length(speed: float, maximum_speed: float, brake_input: float) -> float:
	if brake_input <= 0.0 or speed <= 0.0:
		return 0.0
	var speed_ratio := clampf(speed / maxf(1.0, maximum_speed), 0.0, 1.0)
	return lerpf(10.0, 54.0, speed_ratio) * clampf(brake_input, 0.0, 1.0)

static func finish_emblem_scale(elapsed: float) -> float:
	if elapsed >= FINISH_EMBLEM_DURATION:
		return 1.0
	var progress := clampf(elapsed / FINISH_EMBLEM_DURATION, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - progress, 3.0)
	return lerpf(0.65, 1.0, ease_out) + sin(progress * PI) * 0.08

static func finish_emblem_rotation(elapsed: float) -> float:
	if elapsed >= FINISH_EMBLEM_DURATION:
		return 0.0
	var progress := clampf(elapsed / FINISH_EMBLEM_DURATION, 0.0, 1.0)
	return sin(progress * TAU) * 0.10 * (1.0 - progress)
