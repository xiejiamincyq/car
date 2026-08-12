extends SceneTree

const DifficultyProfile = preload("res://scripts/difficulty_profile.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const RunState = preload("res://scripts/run_state.gd")
const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")
const TrackRuntimeProfile = preload("res://scripts/track_runtime_profile.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	assert(TrackRuntimeProfile.resolve(&"missing").id == &"neon_coast", "Unknown runtime tracks must fall back to the teaching track")
	var patterns := {}
	var spawn_sequences := {}
	for track in TrackCatalog.all():
		var run := RunState.new(GameConfig.MAX_FUEL, GameConfig.FUEL_DRAIN_PER_SECOND, GameConfig.FUEL_GRACE_SECONDS)
		run.configure_track(track)
		assert(run.progression.checkpoint_distances == _float_array(track.checkpoint_distances), "Track checkpoints must configure race progression")
		assert(is_equal_approx(run.progression.finish_distance, float(track.finish_distance)), "Track finish distance must configure race progression")

		var first := TrafficDirector.new(4127)
		var replay := TrafficDirector.new(4127)
		first.configure_track(track)
		replay.configure_track(track)
		assert(first.track_pattern == track.traffic_pattern, "Traffic director must keep the selected track pattern")
		patterns[first.track_pattern] = true
		for difficulty in range(3):
			var profile := DifficultyProfile.for_index(difficulty)
			first.configure_difficulty(profile)
			replay.configure_difficulty(profile)
			var expected_spawn := float(track.traffic_interval_multiplier) * float(profile.traffic_interval_multiplier)
			assert(is_equal_approx(first.effective_spawn_interval_multiplier(), expected_spawn), "Track and difficulty traffic pacing must compose")
			var expected_interval := float(track.lane_event_interval_multiplier) * float(profile.event_interval_multiplier)
			assert(is_equal_approx(first.lane_events.interval_multiplier, expected_interval), "Track and difficulty closure pacing must compose")
		first.set_difficulty_stage(3)
		replay.set_difficulty_stage(3)
		for step in range(80):
			first.tick(0.25, 560.0, 1)
			replay.tick(0.25, 560.0, 1)
		assert(first.spawn_sequence() == replay.spawn_sequence(), "A track profile must stay reproducible for a fixed seed")
		spawn_sequences[first.spawn_sequence()] = true
		_assert_profile_fairness(track)
	assert(patterns.size() == 4, "The four tour stops must have distinct traffic identities")
	assert(spawn_sequences.size() == 4, "Track traffic identities must produce distinct deterministic schedules")
	quit()

func _float_array(values: Array) -> Array[float]:
	var result: Array[float] = []
	for value in values:
		result.append(float(value))
	return result

func _assert_profile_fairness(track: Dictionary) -> void:
	var player_y := TrackGeometry.player_y(720.0)
	for difficulty in range(3):
		for seed in range(4):
			var traffic := TrafficDirector.new(9000 + seed)
			traffic.configure_track(track)
			traffic.configure_difficulty(DifficultyProfile.for_index(difficulty))
			traffic.set_viewport_height(720.0)
			traffic.set_difficulty_stage(3)
			var player_lane := 1
			for step in range(120):
				traffic.tick(0.25, 560.0, player_lane)
				var immediate := traffic.reachable_player_lanes(player_lane, player_y, 72.0)
				assert(not immediate.is_empty(), "%s difficulty %d seed %d must preserve an immediate escape lane" % [track.id, difficulty, seed])
				var reaction := traffic.reachable_player_lanes(player_lane, player_y, GameConfig.MIN_TRAFFIC_GAP)
				if not reaction.is_empty() and not reaction.has(player_lane):
					player_lane = _closest_lane(player_lane, reaction)

func _closest_lane(current_lane: int, candidates: Array[int]) -> int:
	var closest := candidates[0]
	for lane in candidates:
		if abs(lane - current_lane) < abs(closest - current_lane):
			closest = lane
	return closest
