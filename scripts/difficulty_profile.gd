class_name DifficultyProfile
extends RefCounted

const PROFILES := [
	{
		"fuel_spawn_interval": 4.5,
		"repair_spawn_interval": 8.0,
		"supply_active_limit": 2,
		"supply_minimum_road_advance": 136.0,
		"fuel_drain_multiplier": 0.80,
		"integrity_damage_multiplier": 0.2,
		"traffic_interval_multiplier": 1.80,
		"event_interval_multiplier": 1.60,
		"traffic_active_target": 3,
		"lane_warning_multiplier": 1.30,
		"construction_event_limit": 2,
		"early_fast_overtakers": false,
		"combo_window_multiplier": 1.20,
		"random_lane_change_probability": 0.0,
		"double_lane_closure_probability": 0.0,
	},
	{
		"fuel_spawn_interval": 7.0,
		"repair_spawn_interval": 12.0,
		"supply_active_limit": 2,
		"supply_minimum_road_advance": 136.0,
		"fuel_drain_multiplier": 1.2,
		"integrity_damage_multiplier": 0.5,
		"traffic_interval_multiplier": 1.0,
		"event_interval_multiplier": 1.0,
		"traffic_active_target": 5,
		"lane_warning_multiplier": 1.0,
		"construction_event_limit": 3,
		"early_fast_overtakers": true,
		"combo_window_multiplier": 1.0,
		"random_lane_change_probability": 0.18,
		"double_lane_closure_probability": 0.0,
	},
	{
		"fuel_spawn_interval": 10.0,
		"repair_spawn_interval": 18.0,
		"supply_active_limit": 2,
		"supply_minimum_road_advance": 136.0,
		"fuel_drain_multiplier": 2.0,
		"integrity_damage_multiplier": 1.0,
		"traffic_interval_multiplier": 0.50,
		"event_interval_multiplier": 0.60,
		"traffic_active_target": 7,
		"lane_warning_multiplier": 0.85,
		"construction_event_limit": 4,
		"early_fast_overtakers": true,
		"combo_window_multiplier": 0.85,
		"random_lane_change_probability": 0.48,
		"double_lane_closure_probability": 0.23,
	},
]

static func for_index(index: int) -> Dictionary:
	return PROFILES[clampi(index, 0, PROFILES.size() - 1)].duplicate(true)
