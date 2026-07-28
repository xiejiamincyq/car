extends SceneTree

func _init() -> void:
	var config = preload("res://scripts/game_config.gd").new()
	assert(config.ROAD_LANE_COUNT == 3, "MVP road must begin with three lanes")
	assert(config.MAX_SPEED > config.START_SPEED, "Maximum speed must exceed start speed")
	assert(config.MIN_SPAWN_DISTANCE > 0.0, "Traffic spawn distance must be positive")
	assert(config.FUEL_DRAIN_PER_SECOND > 0.0, "Fuel must create time pressure")
	quit()
