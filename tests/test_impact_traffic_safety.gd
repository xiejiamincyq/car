extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
func _init() -> void:
	for seed in range(1, 11):
		var traffic := Traffic.new(seed)
		traffic.set_difficulty_stage(3)
		for step in range(600):
			if step % 25 == 0 and not traffic.vehicles.is_empty():
				traffic.vehicles[0].impact_speed_offset = 80.0 if step % 50 == 0 else -80.0
			traffic.tick(0.05, 560.0, 1)
			assert(not traffic.has_vehicle_overlap(), "Impact recovery must not push NPCs into each other")
			assert(not traffic.has_full_lane_wall(), "Impact recovery must preserve an open lane")
	quit()
