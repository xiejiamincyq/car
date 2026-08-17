class_name DifficultyProfile
extends RefCounted

const PROFILES := [
	{
		"fuel_drain_multiplier": 0.80,
		"traffic_interval_multiplier": 1.15,
		"event_interval_multiplier": 1.35,
		"combo_window_multiplier": 1.20,
		"random_lane_change_probability": 0.0,
		"double_lane_closure_probability": 0.0,
	},
	{
		"fuel_drain_multiplier": 1.0,
		"traffic_interval_multiplier": 1.0,
		"event_interval_multiplier": 1.0,
		"combo_window_multiplier": 1.0,
		"random_lane_change_probability": 0.18,
		"double_lane_closure_probability": 0.0,
	},
	{
		"fuel_drain_multiplier": 1.15,
		"traffic_interval_multiplier": 0.85,
		"event_interval_multiplier": 0.80,
		"combo_window_multiplier": 0.85,
		"random_lane_change_probability": 0.34,
		"double_lane_closure_probability": 0.23,
	},
]

static func for_index(index: int) -> Dictionary:
	return PROFILES[clampi(index, 0, PROFILES.size() - 1)].duplicate(true)
