extends SceneTree

const DifficultyProfile = preload("res://scripts/difficulty_profile.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const MainScene = preload("res://scenes/main.tscn")
const RunState = preload("res://scripts/run_state.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var easy := DifficultyProfile.for_index(0)
	var normal := DifficultyProfile.for_index(1)
	var hard := DifficultyProfile.for_index(2)
	assert(easy.fuel_drain_multiplier < normal.fuel_drain_multiplier and normal.fuel_drain_multiplier < hard.fuel_drain_multiplier, "Difficulty must centrally order fuel pressure")
	assert(easy.traffic_interval_multiplier > normal.traffic_interval_multiplier and normal.traffic_interval_multiplier > hard.traffic_interval_multiplier, "Difficulty must centrally order traffic density")
	assert(easy.event_interval_multiplier > normal.event_interval_multiplier and normal.event_interval_multiplier > hard.event_interval_multiplier, "Difficulty must centrally order road-event frequency")
	assert(easy.combo_window_multiplier > normal.combo_window_multiplier and normal.combo_window_multiplier > hard.combo_window_multiplier, "Difficulty must centrally order combo leniency")
	assert(is_zero_approx(easy.random_lane_change_probability), "Easy difficulty must keep steady traffic predictable")
	assert(normal.random_lane_change_probability > easy.random_lane_change_probability and hard.random_lane_change_probability > normal.random_lane_change_probability, "Random lane-change probability must begin at normal difficulty and rise on hard")
	assert(is_zero_approx(easy.double_lane_closure_probability) and is_zero_approx(normal.double_lane_closure_probability), "Easy and normal difficulty must keep construction diversions to one lane")
	assert(hard.double_lane_closure_probability >= 0.20 and hard.double_lane_closure_probability <= 0.25, "Hard difficulty must occasionally allow a double-lane construction diversion")

	for difficulty in range(3):
		var profile := DifficultyProfile.for_index(difficulty)
		var main = MainScene.instantiate()
		root.add_child(main)
		main.difficulty_index = difficulty
		main._start_new_run()
		assert(main.run.phase == main.RunState.Phase.COUNTDOWN, "Every title difficulty must start through the normal countdown")
		assert(is_equal_approx(main.run.fuel_drain_per_second, GameConfig.FUEL_DRAIN_PER_SECOND * profile.fuel_drain_multiplier), "The selected title difficulty must reach RunState")
		assert(is_equal_approx(main.traffic.spawn_interval_multiplier, profile.traffic_interval_multiplier), "The selected title difficulty must reach traffic spawning")
		assert(is_equal_approx(main.traffic.random_lane_change_probability, profile.random_lane_change_probability), "The selected title difficulty must reach random lane-change behavior")
		assert(is_equal_approx(main.traffic.lane_events.double_lane_probability, profile.double_lane_closure_probability), "The selected title difficulty must reach construction-event scheduling")
		main._process(3.0)
		if difficulty % 2 == 0:
			main.run.mark_clear()
		else:
			main.run.end()
		main._update_hud()
		assert(main.result_screen.visible, "Every difficulty must enter normal clear or failure settlement")
		main.free()

	var random_lane_changes_by_difficulty: Array[int] = []
	for difficulty in range(3):
		var profile := DifficultyProfile.for_index(difficulty)
		var random_lane_change_total := 0
		for seed in range(1, 21):
			var run := RunState.new(GameConfig.MAX_FUEL, GameConfig.FUEL_DRAIN_PER_SECOND, GameConfig.FUEL_GRACE_SECONDS)
			var traffic := TrafficDirector.new(seed)
			run.configure_difficulty(profile)
			traffic.configure_difficulty(profile)
			run.start()
			for second in range(300):
				run.tick(1.0, 560.0, GameConfig.MAX_SPEED)
				traffic.set_difficulty_stage(mini(3, second / 75))
				traffic.tick(1.0, 560.0, 1)
				assert(traffic.all_active_spawns_are_fair(), "20 seeds x 3 difficulties must preserve every traffic invariant")
				assert(traffic.vehicles.size() <= traffic.max_active_vehicles and traffic.allocated_vehicle_count <= traffic.max_active_vehicles, "Difficulty stress must keep traffic objects bounded")
			assert(run.phase == RunState.Phase.RUN_CLEAR or run.phase == RunState.Phase.GAME_OVER, "Each difficulty simulation must reach a valid terminal state")
			random_lane_change_total += traffic.random_lane_change_planned_count
		random_lane_changes_by_difficulty.append(random_lane_change_total)
	assert(random_lane_changes_by_difficulty[0] == 0, "Easy difficulty must never assign random lane changes to steady traffic")
	assert(random_lane_changes_by_difficulty[1] > 0, "Normal difficulty must sometimes assign random lane changes")
	assert(random_lane_changes_by_difficulty[2] > random_lane_changes_by_difficulty[1], "Hard difficulty must assign more random lane changes than normal across fixed seeds")
	quit()
