class_name RaceEffectRenderer
extends RefCounted

const GameFeedback = preload("res://scripts/game_feedback.gd")
const VehicleVisualAnimation = preload("res://scripts/vehicle_visual_animation.gd")

static func draw_vehicle_damage(canvas: CanvasItem, time: float, condition: int, reduced: bool) -> void:
	if condition <= 0:
		return
	var critical := condition >= 2
	canvas.draw_polyline(PackedVector2Array([Vector2(-18,-42), Vector2(-5,-30), Vector2(-12,-21), Vector2(8,-10)]), Color("282d35"), 3.0, true)
	var count := 7 if critical else 3
	for index in range(count):
		var age := fposmod(time * 0.65 + float(index) / count, 1.0)
		var center := Vector2(-12.0 + sin(float(index) * 2.4 + age * 2.0) * 13.0, -38.0 + age * 100.0)
		canvas.draw_circle(center, 5.0 + age * 13.0, Color(0.22, 0.24, 0.28, (1.0-age) * (0.65 if critical else 0.35)))
	if critical:
		for side in [-1.0, 1.0]:
			var length := 10.0 if reduced else 8.0 + 8.0 * (0.5 + sin(time * 13.0) * 0.5)
			canvas.draw_line(Vector2(side * 26.0, 32.0), Vector2(side * 30.0, 32.0 + length), Color("ffb747"), 2.5, true)

static func draw_acceleration(canvas: CanvasItem, car_center: Vector2, animation_time: float, strength: float) -> void:
	var flame_length := VehicleVisualAnimation.acceleration_flame_length(animation_time, strength)
	if flame_length <= 0.0:
		return
	for offset_x in [-19.0, 19.0]:
		var exhaust := car_center + Vector2(offset_x, 43.0)
		canvas.draw_colored_polygon(PackedVector2Array([exhaust + Vector2(-5.0, 0.0), exhaust + Vector2(5.0, 0.0), exhaust + Vector2(0.0, flame_length)]), Color("ff5b37"))
		canvas.draw_colored_polygon(PackedVector2Array([exhaust + Vector2(-2.5, 1.0), exhaust + Vector2(2.5, 1.0), exhaust + Vector2(0.0, flame_length * 0.65)]), Color("ffe66d"))

static func draw_overdrive_speed_streaks(canvas: CanvasItem, viewport_size: Vector2, road_left: float, road_right: float, animation_time: float, strength: float, reduced_flashing: bool) -> void:
	if strength <= 0.0:
		return
	var line_count := 4 if reduced_flashing else 8
	var travel := fposmod(animation_time * 980.0, viewport_size.y + 180.0)
	for index in range(line_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var rank := float(index / 2)
		var edge_x := road_left if side < 0.0 else road_right
		var x := edge_x - side * (34.0 + rank * 42.0)
		var y := fposmod(travel + index * 109.0, viewport_size.y + 180.0) - 90.0
		var length := lerpf(44.0, 126.0, strength)
		var color := Color(0.22, 0.94, 1.0, (0.16 + rank * 0.025) * strength)
		canvas.draw_line(Vector2(x, y - length), Vector2(x, y), color, 3.0)

static func draw_overdrive_ignition(canvas: CanvasItem, car_center: Vector2, animation_time: float, strength: float, reduced_flashing: bool) -> void:
	var flame_length := VehicleVisualAnimation.overdrive_flame_length(animation_time, strength, reduced_flashing)
	if flame_length <= 0.0:
		return
	var glow_alpha := VehicleVisualAnimation.overdrive_glow_alpha(animation_time, strength, reduced_flashing)
	canvas.draw_circle(car_center, 48.0 + strength * 8.0, Color(0.18, 0.92, 1.0, glow_alpha * 0.42))
	canvas.draw_arc(car_center, 43.0 + strength * 5.0, 0.0, TAU, 30, Color(0.35, 0.98, 1.0, glow_alpha), 3.0)
	for offset_x in [-19.0, 19.0]:
		var exhaust := car_center + Vector2(offset_x, 42.0)
		canvas.draw_colored_polygon(PackedVector2Array([exhaust + Vector2(-7.0, 0.0), exhaust + Vector2(7.0, 0.0), exhaust + Vector2(0.0, flame_length)]), Color(0.10, 0.90, 1.0, 0.88 * strength))
		canvas.draw_colored_polygon(PackedVector2Array([exhaust + Vector2(-4.0, 1.0), exhaust + Vector2(4.0, 1.0), exhaust + Vector2(0.0, flame_length * 0.74)]), Color(1.0, 0.43, 0.10, 0.96 * strength))
		canvas.draw_colored_polygon(PackedVector2Array([exhaust + Vector2(-2.0, 2.0), exhaust + Vector2(2.0, 2.0), exhaust + Vector2(0.0, flame_length * 0.48)]), Color(1.0, 0.93, 0.46, strength))

static func draw_overdrive_afterimages(canvas: CanvasItem, texture: Texture2D, car_center: Vector2, player_size: Vector2, rotation: float, scale: Vector2, screen_offset: Vector2, strength: float) -> void:
	if texture == null or strength <= 0.0:
		return
	var player_rect := Rect2(-player_size * 0.5, player_size)
	for layer_index in range(1, -1, -1):
		var trail_offset := Vector2(0.0, 27.0 * float(layer_index + 1))
		var alpha := VehicleVisualAnimation.overdrive_afterimage_alpha(layer_index, strength)
		canvas.draw_set_transform(screen_offset + car_center + trail_offset, rotation, scale)
		canvas.draw_texture_rect(texture, player_rect, false, Color(0.35, 0.95, 1.0, alpha))
	canvas.draw_set_transform(screen_offset)

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

static func draw_speed_lines(canvas: CanvasItem, viewport_size: Vector2, speed: float, maximum_speed: float, animation_time: float) -> void:
	var line_count := VehicleVisualAnimation.speed_line_count(speed, maximum_speed)
	if line_count <= 0:
		return
	var speed_ratio := clampf(speed / maxf(1.0, maximum_speed), 0.0, 1.0)
	var travel := fposmod(animation_time * speed * 1.7, viewport_size.y + 160.0)
	for index in range(line_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var rank := float(index / 2)
		var x := viewport_size.x * 0.5 + side * (360.0 + rank * 58.0)
		var y := fposmod(travel + index * 137.0, viewport_size.y + 160.0) - 80.0
		var length := lerpf(28.0, 105.0, speed_ratio)
		canvas.draw_line(Vector2(x, y - length), Vector2(x, y), Color(0.55, 0.94, 1.0, 0.16 + speed_ratio * 0.30), 3.0)
