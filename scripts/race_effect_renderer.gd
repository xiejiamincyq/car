class_name RaceEffectRenderer
extends RefCounted

const GameFeedback = preload("res://scripts/game_feedback.gd")
const VehicleVisualAnimation = preload("res://scripts/vehicle_visual_animation.gd")

static func draw_acceleration(canvas: CanvasItem, car_center: Vector2, animation_time: float, strength: float) -> void:
	var flame_length := VehicleVisualAnimation.acceleration_flame_length(animation_time, strength)
	if flame_length <= 0.0:
		return
	for offset_x in [-19.0, 19.0]:
		var exhaust := car_center + Vector2(offset_x, 43.0)
		canvas.draw_colored_polygon(PackedVector2Array([exhaust + Vector2(-5.0, 0.0), exhaust + Vector2(5.0, 0.0), exhaust + Vector2(0.0, flame_length)]), Color("ff5b37"))
		canvas.draw_colored_polygon(PackedVector2Array([exhaust + Vector2(-2.5, 1.0), exhaust + Vector2(2.5, 1.0), exhaust + Vector2(0.0, flame_length * 0.65)]), Color("ffe66d"))

static func draw_braking(canvas: CanvasItem, car_center: Vector2, animation_time: float, strength: float, speed: float, maximum_speed: float) -> void:
	var light_alpha := VehicleVisualAnimation.brake_light_alpha(animation_time, strength)
	if light_alpha <= 0.0:
		return
	var streak_length := VehicleVisualAnimation.brake_streak_length(speed, maximum_speed, strength)
	for offset_x in [-20.0, 20.0]:
		var tire_position := car_center + Vector2(offset_x, 42.0)
		var tire_end := tire_position + Vector2(0.0, streak_length)
		canvas.draw_line(tire_position, tire_end, Color(0.62, 0.66, 0.68, light_alpha * 0.55), 7.0)
		canvas.draw_line(tire_position, tire_end, Color(0.03, 0.04, 0.06, light_alpha * 0.82), 3.0)
		canvas.draw_circle(car_center + Vector2(offset_x, 34.0), 6.0, Color(1.0, 0.12, 0.1, light_alpha))
		canvas.draw_circle(car_center + Vector2(offset_x, 34.0), 2.5, Color(1.0, 0.86, 0.45, light_alpha))

static func draw_pickup_bursts(canvas: CanvasItem, feedback: GameFeedback, burst_color: Color) -> void:
	for burst in feedback.pickup_bursts:
		var life_ratio := clampf(float(burst.life) / GameFeedback.PICKUP_BURST_DURATION, 0.0, 1.0)
		var progress := 1.0 - life_ratio
		var radius := lerpf(18.0, 58.0, progress)
		canvas.draw_arc(burst.position, radius, 0.0, TAU, 24, Color(burst_color, life_ratio), 4.0)
		for angle_index in range(4):
			var direction := Vector2.from_angle(float(angle_index) * PI * 0.5)
			canvas.draw_circle(burst.position + direction * radius, 4.0, Color.WHITE)

static func draw_pass_streaks(canvas: CanvasItem, feedback: GameFeedback, warning_color: Color) -> void:
	for streak in feedback.pass_streaks:
		var life_ratio := clampf(float(streak.life) / GameFeedback.PASS_STREAK_DURATION, 0.0, 1.0)
		var is_near_miss := bool(streak.near_miss)
		var line_count := 6 if is_near_miss else 3
		var line_length := 92.0 if is_near_miss else 58.0
		var line_color := Color(warning_color, life_ratio) if is_near_miss else Color("42e8df", life_ratio * 0.82)
		var streak_position: Vector2 = streak.position
		for line_index in range(line_count):
			var side := -1.0 if line_index % 2 == 0 else 1.0
			var spacing := 28.0 + float(line_index / 2) * 9.0
			var start: Vector2 = streak_position + Vector2(side * spacing, -line_length * 0.5)
			canvas.draw_line(start, start + Vector2(0.0, line_length), line_color, 5.0 if is_near_miss else 3.0)

static func draw_collision_ring(canvas: CanvasItem, car_center: Vector2, remaining: float, warning_color: Color) -> void:
	var alpha := VehicleVisualAnimation.collision_ring_alpha(remaining)
	if alpha <= 0.0:
		return
	var progress := 1.0 - remaining / VehicleVisualAnimation.COLLISION_DURATION
	canvas.draw_arc(car_center, lerpf(42.0, 82.0, progress), 0.0, TAU, 32, Color(warning_color, alpha), 5.0)
