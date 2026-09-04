class_name VehicleVisualAnimation
extends RefCounted

const COLLISION_DURATION := 0.55
const MAX_COLLISION_ROTATION := 0.18
const FINISH_EMBLEM_DURATION := 0.75
const MAX_STEERING_ROTATION := deg_to_rad(15.0)
const VEHICLE_LENGTH_CORRECTION := 1.22

static func acceleration_flame_length(time_seconds: float, throttle: float) -> float:
	if throttle <= 0.0:
		return 0.0
	var pulse := 0.5 + 0.5 * sin(time_seconds * 34.0)
	return lerpf(8.0, 24.0, clampf(throttle, 0.0, 1.0) * (0.65 + pulse * 0.35))

static func overdrive_flame_length(time_seconds: float, strength: float, reduced_flashing: bool) -> float:
	if strength <= 0.0:
		return 0.0
	var pulse := 1.0 if reduced_flashing else 0.82 + 0.18 * sin(time_seconds * 42.0)
	return lerpf(30.0, 54.0, clampf(strength, 0.0, 1.0)) * pulse

static func overdrive_glow_alpha(time_seconds: float, strength: float, reduced_flashing: bool) -> float:
	if strength <= 0.0:
		return 0.0
	var pulse := 1.0 if reduced_flashing else 0.78 + 0.22 * sin(time_seconds * 18.0)
	return clampf(strength, 0.0, 1.0) * 0.34 * pulse

static func overdrive_afterimage_alpha(layer_index: int, strength: float) -> float:
	var layer_alpha := 0.22 if layer_index <= 0 else 0.10
	return layer_alpha * clampf(strength, 0.0, 1.0)

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

static func steering_rotation(steering_strength: float) -> float:
	return clampf(steering_strength, -1.0, 1.0) * MAX_STEERING_ROTATION

static func traffic_facing_rotation() -> float:
	return 0.0

static func traffic_lane_change_rotation(lane_position: float, target_lane: float, change_started: bool) -> float:
	if not change_started:
		return 0.0
	var remaining_distance := absf(target_lane - lane_position)
	if is_zero_approx(remaining_distance):
		return 0.0
	return steering_rotation(signf(target_lane - lane_position))

static func traffic_lane_change_arrow_points(body_half_width: float, direction: float) -> PackedVector2Array:
	var side := 1.0 if direction >= 0.0 else -1.0
	var inner_x := maxf(0.0, body_half_width) + 9.0
	var shoulder_x := inner_x + 20.0
	var tip_x := inner_x + 38.0
	return PackedVector2Array([
		Vector2(inner_x * side, -6.0),
		Vector2(shoulder_x * side, -6.0),
		Vector2(shoulder_x * side, -15.0),
		Vector2(tip_x * side, 0.0),
		Vector2(shoulder_x * side, 15.0),
		Vector2(shoulder_x * side, 6.0),
		Vector2(inner_x * side, 6.0),
	])

static func corrected_vehicle_size(source_size: Vector2) -> Vector2:
	return Vector2(source_size.x, source_size.y * VEHICLE_LENGTH_CORRECTION)

static func speed_line_count(speed: float, maximum_speed: float) -> int:
	var ratio := clampf(speed / maxf(1.0, maximum_speed), 0.0, 1.0)
	return maxi(0, floori((ratio - 0.30) * 10.0))
