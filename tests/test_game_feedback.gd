extends SceneTree

const GameFeedback = preload("res://scripts/game_feedback.gd")
const VisualStyle = preload("res://scripts/visual_style.gd")

func _init() -> void:
	var feedback := GameFeedback.new(24)
	for collision_index in range(20):
		feedback.spawn_collision(Vector2(100.0, 200.0), 200.0 + collision_index * 30.0, 760.0)
	assert(feedback.sparks.size() <= 24, "Procedural collision sparks must respect their hard object cap")
	for spark in feedback.sparks:
		assert(is_finite(spark.position.x) and is_finite(spark.position.y) and is_finite(spark.velocity.x) and is_finite(spark.velocity.y) and is_finite(spark.life), "Spark state must never contain NaN or infinity")
	feedback.tick(2.0, 100.0, 0)
	assert(feedback.sparks.is_empty(), "Expired sparks must be recycled promptly")
	assert(feedback.shake_magnitude_for_speed(700.0, 760.0) > feedback.shake_magnitude_for_speed(200.0, 760.0), "High-speed collisions must produce stronger shake")

	feedback.tick(0.0, 29.9, 0)
	assert(feedback.low_fuel_tier == GameFeedback.FuelTier.LOW and feedback.low_fuel_text() == "燃油偏低", "The first fuel threshold must use an explicit text warning")
	feedback.tick(0.0, 14.9, 0)
	assert(feedback.low_fuel_tier == GameFeedback.FuelTier.CRITICAL and feedback.low_fuel_text() == "燃油危险", "The critical threshold must be distinct in text")
	feedback.flashing_enabled = false
	feedback.tick(0.25, 10.0, 0)
	assert(feedback.is_fuel_warning_visible(), "Disabling flashing must keep a steady warning instead of hiding it")

	feedback.tick(0.0, 100.0, 1)
	assert(feedback.stage_banner_text == "赛段 2" and is_zero_approx(feedback.stage_transition_mix), "Stage change must start a clear text banner and colour transition")
	feedback.announce_checkpoint(1, 12.0)
	assert(feedback.stage_banner_text == "检查点 1 / 3　燃油 +12", "Checkpoint feedback must explain both progress and its fuel reward")
	feedback.tick(1.0, 100.0, 1)
	assert(is_equal_approx(feedback.stage_transition_mix, 0.5), "Stage colour transition must interpolate over its configured duration")
	var midway := VisualStyle.road_color_for_transition(feedback.previous_stage, feedback.current_stage, feedback.stage_transition_mix)
	assert(midway != VisualStyle.ROAD and midway != VisualStyle.STAGE_ROAD_COLORS[1], "Mid-transition road colour must be visibly interpolated")
	feedback.tick(1.1, 100.0, 1)
	assert(is_equal_approx(feedback.stage_transition_mix, 1.0) and feedback.stage_banner_text.is_empty(), "Stage banner and interpolation must finish cleanly")

	for burst_index in range(20):
		feedback.spawn_pickup(Vector2(100.0 + burst_index, 220.0))
	assert(feedback.pickup_bursts.size() <= GameFeedback.MAX_PICKUP_BURSTS, "Pickup bursts must respect a hard object cap")
	for coin_index in range(24):
		feedback.spawn_coin(Vector2(180.0 + coin_index, 260.0), coin_index % 3 + 1)
	assert(feedback.coin_bursts.size() <= GameFeedback.MAX_COIN_BURSTS, "Coin star bursts must respect a separate hard object cap")
	assert(feedback.coin_bursts.back().combo_multiplier == 3, "Coin feedback must retain the non-colour combo intensity cue")
	for pass_index in range(30):
		feedback.spawn_pass(Vector2(300.0, 400.0 + pass_index), pass_index % 2 == 1)
	assert(feedback.pass_streaks.size() <= GameFeedback.MAX_PASS_STREAKS, "Pass streaks must respect a hard object cap")
	assert(feedback.pass_streaks.back().near_miss, "Near-miss streaks must retain a non-colour intensity cue")
	feedback.start_finish()
	assert(feedback.finish_remaining > 0.0, "Run clear must start a bounded finish effect")
	feedback.tick(3.0, 100.0, 1)
	assert(feedback.pickup_bursts.is_empty() and feedback.coin_bursts.is_empty() and feedback.pass_streaks.is_empty(), "Transient pickup, coin, and pass effects must recycle promptly")
	assert(is_zero_approx(feedback.finish_remaining), "Finish effects must end deterministically")
	quit()
