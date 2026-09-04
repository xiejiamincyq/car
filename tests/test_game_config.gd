extends SceneTree

func _init() -> void:
	var config = preload("res://scripts/game_config.gd").new()
	assert(config.ROAD_LANE_COUNT == 3, "MVP road must begin with three lanes")
	assert(config.MAX_SPEED > config.START_SPEED, "Maximum speed must exceed start speed")
	assert(is_equal_approx(config.OVERDRIVE_DURATION_SECONDS, 4.5), "Playtest tuning must extend overdrive duration by two seconds")
	assert(is_equal_approx(config.OVERDRIVE_RAMP_IN_SECONDS, 0.70), "Overdrive acceleration ramp must take twice as long as the original value")
	assert(is_equal_approx(config.OVERDRIVE_RAMP_OUT_SECONDS, 1.00), "Overdrive deceleration ramp must take twice as long as the original value")
	assert(is_equal_approx(config.OVERDRIVE_FUEL_COST_RATIO, 0.15), "A complete overdrive must commit fifteen percent of the maximum fuel tank")
	assert(is_equal_approx(config.OVERDRIVE_SPEED_BONUS * config.HUD_SPEED_SCALE, 100.0), "Overdrive must add 100 km/h in the same units shown by the HUD")
	assert(is_equal_approx(config.OVERDRIVE_ACCELERATION_BONUS * config.HUD_SPEED_SCALE, 280.0), "Overdrive acceleration must use the HUD speed unit contract")
	assert(config.MIN_SPAWN_DISTANCE > 0.0, "Traffic spawn distance must be positive")
	assert(config.FUEL_DRAIN_PER_SECOND > 0.0, "Fuel must create time pressure")
	assert(is_equal_approx(config.COIN_ROUTE_INTERVAL_DISTANCE, 2200.0), "Coin route frequency must be halved without breaking each route's internal guidance")
	assert(is_equal_approx(config.COLLISION_SPEED_PENALTY_MULTIPLIER, 1.08), "Every vehicle collision penalty must increase by a modest eight percent")
	assert(config.LANE_EVENT_CONE_SPEED_PENALTY_RATIO > 0.0 and config.LANE_EVENT_CONE_SPEED_PENALTY_RATIO <= 0.15, "Cone collisions must be noticeable without becoming run-ending crashes")
	assert(config.LANE_EVENT_CONE_HIT_COOLDOWN >= 0.5, "Repeated cone contacts must have a damage-protection window")
	quit()
