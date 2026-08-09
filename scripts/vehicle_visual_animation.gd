class_name VehicleVisualAnimation
extends RefCounted

const COLLISION_DURATION := 0.55
const MAX_COLLISION_ROTATION := 0.18

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
