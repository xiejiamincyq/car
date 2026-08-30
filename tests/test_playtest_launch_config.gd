extends SceneTree

const PlaytestLaunchConfig = preload("res://tests/playtest_launch_config.gd")

func _init() -> void:
	var valid := PlaytestLaunchConfig.parse(PackedStringArray(["storm_ridge", "driftwing", "standard", "13"]))
	assert(valid.valid, "A known track, vehicle, difficulty, and non-negative seed must form a playtest launch")
	assert(valid.track_id == &"storm_ridge" and valid.vehicle_id == &"driftwing", "The launch config must preserve catalog IDs")
	assert(valid.difficulty_index == 1 and valid.run_seed == 13, "The launch config must normalize standard difficulty and seed")

	var numeric_difficulty := PlaytestLaunchConfig.parse(PackedStringArray(["neon_coast", "pulse_gt", "2", "11"]))
	assert(numeric_difficulty.valid and numeric_difficulty.difficulty_index == 2, "Difficulty indices zero through two must be accepted")

	assert(not PlaytestLaunchConfig.parse(PackedStringArray(["missing", "pulse_gt", "standard", "11"])).valid, "Unknown tracks must be rejected")
	assert(not PlaytestLaunchConfig.parse(PackedStringArray(["neon_coast", "missing", "standard", "11"])).valid, "Unknown vehicles must be rejected")
	assert(not PlaytestLaunchConfig.parse(PackedStringArray(["neon_coast", "pulse_gt", "nightmare", "11"])).valid, "Unknown difficulties must be rejected")
	assert(not PlaytestLaunchConfig.parse(PackedStringArray(["neon_coast", "pulse_gt", "standard", "-1"])).valid, "Negative seeds must be rejected")
	assert(not PlaytestLaunchConfig.parse(PackedStringArray(["neon_coast"])).valid, "Incomplete launch arguments must be rejected")
	quit()
