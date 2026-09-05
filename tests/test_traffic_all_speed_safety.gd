extends SceneTree

const DifficultyProfile = preload("res://scripts/difficulty_profile.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

const STEP_SECONDS := 0.10
const STEPS_PER_CASE := 600

func _init() -> void:
	var player_speeds := [0.0, 180.0, GameConfig.START_SPEED, 560.0, GameConfig.MAX_SPEED, GameConfig.MAX_SPEED + GameConfig.OVERDRIVE_SPEED_BONUS]
	player_speeds.append(-1.0)
	for seed in range(1, 21):
		for player_speed in player_speeds:
			var traffic := TrafficDirector.new(seed, GameConfig.ROAD_LANE_COUNT, GameConfig.MIN_SPAWN_DISTANCE, GameConfig.MIN_TRAFFIC_GAP)
			traffic.set_viewport_height(720.0)
			traffic.set_difficulty_stage(3)
			traffic.configure_difficulty(DifficultyProfile.for_index(2))
			for step in range(STEPS_PER_CASE):
				var player_lane := (seed + step / 90) % GameConfig.ROAD_LANE_COUNT
				var actual_speed: float = player_speed if player_speed >= 0.0 else (0.5 + 0.5 * sin(float(step) * 0.035)) * (GameConfig.MAX_SPEED + GameConfig.OVERDRIVE_SPEED_BONUS)
				traffic.tick(STEP_SECONDS, actual_speed, player_lane)
				assert(not traffic.has_full_lane_wall(), "Seed %d speed %.0f must never form a three-lane NPC wall at step %d: %s" % [seed, player_speed, step, _traffic_signature(traffic.vehicles)])
				assert(not traffic.has_vehicle_overlap(), "Seed %d speed %.0f must never allow NPC body clipping at step %d: %s" % [seed, player_speed, step, _traffic_signature(traffic.vehicles)])
	quit()

func _traffic_signature(vehicles: Array) -> String:
	var parts := PackedStringArray()
	for vehicle in vehicles:
		parts.append("kind=%d lane=%d pos=%.2f target=%d y=%.1f speed=%.0f warn=%s moving=%s" % [vehicle.kind, vehicle.lane, vehicle.lane_position, vehicle.target_lane, vehicle.y, vehicle.cruise_speed, vehicle.warning_started, vehicle.change_started])
	return "; ".join(parts)
