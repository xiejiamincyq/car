class_name CoinRenderer
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")
const GameFeedback = preload("res://scripts/game_feedback.gd")

const COIN_RADIUS := 18.0
const MIN_SPIN_SCALE := 0.30
const REDUCED_FLASHING_SCALE := 0.92
const MAX_ATTRACTION_OFFSET := 22.0
const GOLD_DARK := Color("9a4e08")
const GOLD_RIM := Color("ffb51d")
const GOLD_FACE := Color("ffd95a")
const GOLD_HIGHLIGHT := Color("fff2a3")
const GOLD_GLOW := Color(1.0, 0.63, 0.08, 0.18)

static func spin_scale(animation_time: float, coin_id: int, reduced_flashing: bool) -> float:
	if reduced_flashing:
		return REDUCED_FLASHING_SCALE
	var phase := animation_time * 5.2 + float(coin_id) * 0.73
	return lerpf(MIN_SPIN_SCALE, 1.0, absf(cos(phase)))

static func attraction_offset(coin_center: Vector2, player_center: Vector2) -> Vector2:
	var delta := player_center - coin_center
	var distance := delta.length()
	if is_zero_approx(distance) or distance >= GameConfig.COIN_ATTRACTION_RADIUS:
		return Vector2.ZERO
	var ratio := 1.0 - distance / GameConfig.COIN_ATTRACTION_RADIUS
	return delta.normalized() * minf(MAX_ATTRACTION_OFFSET, ratio * ratio * MAX_ATTRACTION_OFFSET)

static func draw_coins(
	canvas: CanvasItem,
	coins: Array,
	road_left: float,
	lane_width: float,
	player_center: Vector2,
	animation_time: float,
	high_contrast: bool,
	reduced_flashing: bool,
	screen_offset: Vector2
) -> void:
	for coin in coins:
		if coin.collected:
			continue
		var road_center := Vector2(road_left + lane_width * (coin.lane_position + 0.5), coin.y)
		var center := road_center + attraction_offset(road_center, player_center)
		var scale_x := spin_scale(animation_time, coin.id, reduced_flashing)
		canvas.draw_set_transform(screen_offset)
		canvas.draw_circle(center, COIN_RADIUS + 10.0, GOLD_GLOW if not high_contrast else Color(1.0, 0.92, 0.18, 0.25))
		canvas.draw_set_transform(screen_offset + center, 0.0, Vector2(scale_x, 1.0))
		canvas.draw_circle(Vector2.ZERO, COIN_RADIUS + 2.5, Color("4a2508"))
		canvas.draw_circle(Vector2.ZERO, COIN_RADIUS, GOLD_RIM if not high_contrast else Color("ffff28"))
		canvas.draw_circle(Vector2.ZERO, COIN_RADIUS - 4.0, GOLD_FACE if not high_contrast else Color("fff57a"))
		canvas.draw_arc(Vector2.ZERO, COIN_RADIUS - 6.5, -2.65, -0.45, 18, GOLD_HIGHLIGHT, 2.2, true)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(2.0, -11.0), Vector2(-6.0, 1.0), Vector2(-1.0, 1.0),
			Vector2(-4.0, 11.0), Vector2(7.0, -3.0), Vector2(2.0, -3.0),
		]), GOLD_DARK)
	canvas.draw_set_transform(screen_offset)

static func draw_bursts(canvas: CanvasItem, feedback, screen_offset: Vector2) -> void:
	canvas.draw_set_transform(screen_offset)
	for burst in feedback.coin_bursts:
		var life_ratio := clampf(float(burst.life) / GameFeedback.COIN_BURST_DURATION, 0.0, 1.0)
		var progress := 1.0 - life_ratio
		var center: Vector2 = burst.position
		var radius := lerpf(18.0, 48.0, progress)
		var alpha := life_ratio * life_ratio
		var multiplier := clampi(int(burst.combo_multiplier), 1, 3)
		canvas.draw_arc(center, radius * 0.72, 0.0, TAU, 28, Color(1.0, 0.72, 0.12, alpha * 0.72), 3.0, true)
		for ray_index in range(4 + multiplier * 2):
			var angle := TAU * float(ray_index) / float(4 + multiplier * 2) + progress * 0.35
			var direction := Vector2.from_angle(angle)
			var inner := center + direction * radius * 0.52
			var outer := center + direction * radius
			canvas.draw_line(inner, outer, Color(1.0, 0.86, 0.28, alpha), 3.0, true)
			canvas.draw_circle(outer, 2.5 + float(multiplier) * 0.4, Color(1.0, 0.95, 0.62, alpha))
