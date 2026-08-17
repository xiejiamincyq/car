extends SceneTree

func _init() -> void:
	var config = preload("res://scripts/game_config.gd").new()
	assert(config.ROAD_LANE_COUNT == 3, "MVP road must begin with three lanes")
	assert(config.MAX_SPEED > config.START_SPEED, "Maximum speed must exceed start speed")
	assert(config.MIN_SPAWN_DISTANCE > 0.0, "Traffic spawn distance must be positive")
	assert(config.FUEL_DRAIN_PER_SECOND > 0.0, "Fuel must create time pressure")
	assert(config.LANE_EVENT_CONE_SPEED_PENALTY_RATIO > 0.0 and config.LANE_EVENT_CONE_SPEED_PENALTY_RATIO <= 0.15, "Cone collisions must be noticeable without becoming run-ending crashes")
	assert(config.LANE_EVENT_CONE_HIT_COOLDOWN >= 0.5, "Repeated cone contacts must have a damage-protection window")
	quit()
