extends SceneTree

const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	for seed in range(1, 11):
		var director = TrafficDirector.new(seed)
		for _second in range(30):
			director.tick(1.0, 500.0, 1)
			assert(director.all_active_spawns_are_fair(), "Each of ten fixed seeds must keep actual spawns fair for 15 seconds")
	var sequence_a = TrafficDirector.new(99)
	var sequence_b = TrafficDirector.new(99)
	for _second in range(30):
		sequence_a.tick(1.0, 500.0, 1)
		sequence_b.tick(1.0, 500.0, 1)
	assert(sequence_a.spawn_sequence() == sequence_b.spawn_sequence(), "Fixed seeds must reproduce the actual 30-second spawn sequence")
	sequence_a.reset()
	for _second in range(30):
		sequence_a.tick(1.0, 500.0, 1)
	assert(sequence_a.spawn_sequence() == sequence_b.spawn_sequence(), "Reset must reproduce the actual 30-second sequence")

	var director = TrafficDirector.new(73)
	for _second in range(300):
		director.tick(1.0, 500.0, 1)
	assert(director.vehicles.size() <= director.max_active_vehicles, "Five minutes must keep active traffic bounded")
	assert(director.allocated_vehicle_count <= director.max_active_vehicles, "Traffic must reuse a bounded object pool")

	director.reset()
	var changer = director.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 1, 120.0)
	director.vehicles.append(changer)
	director.update_vehicle(changer, 0.1, 500.0)
	assert(changer.warning_remaining > 0.0, "Lane-change warning must begin while the car is visible")
	assert(abs(changer.target_lane - changer.lane) == 1, "Lane change must only target an adjacent lane")
	assert(director.is_lane_change_safe(changer), "Lane change target must be safe before the move")
	changer.warning_remaining = 0.01
	director.update_vehicle(changer, 0.1, 500.0)
	assert(changer.change_started, "Lane change must begin after its visible warning")
	assert(changer.lane_position != float(changer.lane), "Lane change must move smoothly instead of jumping lanes")
	var other_changer = director.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, 120.0)
	other_changer.target_lane = changer.target_lane
	other_changer.warning_started = true
	other_changer.warning_remaining = 0.5
	director.vehicles.append(other_changer)
	assert(not director.is_lane_change_safe(other_changer), "Two cars must not reserve the same merge lane")

	var overtaker = director.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 0, 820.0)
	director.update_vehicle(overtaker, 1.0, 760.0)
	assert(overtaker.overtake_warning_remaining >= 1.0, "Fast overtaker must warn for at least one visible second before collision risk")
	assert(director.is_fast_spawn_fair(760.0, 1), "Fast overtaker must use the player-speed reaction-distance fairness check")
	assert(TrafficDirector.fast_warning_y(700.0) >= 0.0 and TrafficDirector.fast_warning_y(700.0) <= 720.0, "Fast warning must be visible in the viewport")

	for stage in range(4):
		var staged_a = TrafficDirector.new(409)
		var staged_b = TrafficDirector.new(409)
		staged_a.set_difficulty_stage(stage)
		staged_b.set_difficulty_stage(stage)
		for _second in range(30):
			staged_a.tick(1.0, 500.0, 1)
			staged_b.tick(1.0, 500.0, 1)
		assert(staged_a.spawn_sequence() == staged_b.spawn_sequence(), "Every difficulty stage must retain fixed-seed determinism")
		for vehicle in staged_a.vehicles:
			assert(vehicle.kind <= staged_a.maximum_kind_for_stage(), "A stage must not spawn a vehicle type scheduled for a later stage")
	var early = TrafficDirector.new(88)
	early.set_difficulty_stage(0)
	for _second in range(30):
		early.tick(1.0, 500.0, 1)
	for vehicle in early.vehicles:
		assert(vehicle.kind == TrafficDirector.Kind.STEADY_SLOW, "The protected opening must only use steady traffic")
	var lane_schedule = TrafficDirector.new(5)
	lane_schedule.set_difficulty_stage(1)
	var stage_one_warning := lane_schedule.lane_change_warning_duration()
	lane_schedule.set_difficulty_stage(3)
	assert(lane_schedule.lane_change_warning_duration() < stage_one_warning, "Late stages must increase lane-change frequency through shorter warnings")

	director.reset()
	assert(director.vehicles.is_empty(), "Restart must clear actual active traffic")
	quit()
