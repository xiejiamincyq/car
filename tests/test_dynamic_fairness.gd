extends SceneTree

const GameConfig = preload("res://scripts/game_config.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

const SIMULATION_SECONDS := 60.0
const STEP_SECONDS := 0.25
const PLAYER_SPEEDS := [360.0, 560.0, 760.0]

func _init() -> void:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	var lane_change_time := lane_width / GameConfig.STEERING_SPEED
	for stage in range(4):
		var staged := TrafficDirector.new(500 + stage)
		staged.set_difficulty_stage(stage)
		assert(staged.lane_change_warning_duration() >= lane_change_time + 0.1, "Stage %d warning must include steering time and a reaction margin" % stage)

	for viewport_height in [720.0, 1080.0]:
		var player_y := TrackGeometry.player_y(viewport_height)
		for seed in range(1, 21):
			for initial_lane in range(GameConfig.ROAD_LANE_COUNT):
				for player_speed in PLAYER_SPEEDS:
					var traffic := TrafficDirector.new(seed, GameConfig.ROAD_LANE_COUNT, GameConfig.MIN_SPAWN_DISTANCE, GameConfig.MIN_TRAFFIC_GAP)
					traffic.set_viewport_height(viewport_height)
					var player_lane := initial_lane
					for step in range(int(SIMULATION_SECONDS / STEP_SECONDS)):
						traffic.set_difficulty_stage(mini(3, int(step * STEP_SECONDS / 15.0)))
						traffic.tick(STEP_SECONDS, player_speed, player_lane)
						var immediate: Array[int] = traffic.reachable_player_lanes(player_lane, player_y, 72.0)
						if immediate.is_empty():
							_fail_unreachable(seed, viewport_height, player_lane, player_speed, step, traffic, "no immediate collision-free lane")
							return
						var reaction_clearance := maxf(GameConfig.MIN_TRAFFIC_GAP, player_speed * 0.5)
						var reachable: Array[int] = traffic.reachable_player_lanes(player_lane, player_y, reaction_clearance)
						if not reachable.is_empty() and not reachable.has(player_lane):
							player_lane = _closest_lane(player_lane, reachable)
						assert(traffic.vehicles.size() <= traffic.max_active_vehicles and traffic.allocated_vehicle_count <= traffic.max_active_vehicles, "Dynamic simulation must keep traffic bounded")
	quit()

func _closest_lane(current_lane: int, candidates: Array[int]) -> int:
	var closest := candidates[0]
	for lane in candidates:
		if abs(lane - current_lane) < abs(closest - current_lane):
			closest = lane
	return closest

func _fail_unreachable(seed: int, viewport_height: float, player_lane: int, player_speed: float, step: int, traffic, reason: String) -> void:
	var traffic_state: PackedStringArray = ["event_state=%d closed=%s cores=%s" % [traffic.lane_events.state, str(traffic.lane_events.closed_lanes()), str(traffic.lane_events.core_markers(viewport_height))]]
	for vehicle in traffic.vehicles:
		traffic_state.append("kind=%d lane=%d target=%d y=%.1f" % [vehicle.kind, vehicle.lane, vehicle.target_lane, vehicle.y])
	push_error("Seed %d viewport %.0f lane %d speed %.0f %s at %.2fs: %s" % [seed, viewport_height, player_lane, player_speed, reason, step * STEP_SECONDS, "; ".join(traffic_state)])
	quit(1)
