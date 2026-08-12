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
	var sedan_variant = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, 100.0)
	var van_variant = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 100.0)
	assert(sedan_variant.visual_variant != van_variant.visual_variant, "Steady traffic must rotate between distinct sedan and van visuals")
	assert(sedan_variant.cruise_speed >= 180.0 and sedan_variant.cruise_speed <= 220.0, "Default NPC road speed should stay near 200")
	assert(director.target_active_vehicles < director.max_active_vehicles, "Visible traffic density and object-pool capacity must remain separate budgets")
	var initial_y: float = sedan_variant.y
	director.update_vehicle(sedan_variant, 1.0, 500.0)
	assert(is_equal_approx(sedan_variant.y - initial_y, 500.0 - sedan_variant.cruise_speed), "NPC screen motion must reflect player speed minus its road speed")
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

	director.reset()
	var random_steady_changer = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 120.0)
	random_steady_changer.target_lane = 0
	random_steady_changer.lane_change_enabled = true
	director.vehicles.append(random_steady_changer)
	director.update_vehicle(random_steady_changer, 0.1, 500.0)
	assert(random_steady_changer.kind == TrafficDirector.Kind.STEADY_SLOW, "Random lane changes must preserve the vehicle's original visual kind")
	assert(random_steady_changer.warning_remaining > 0.0, "Random steady-traffic lane changes must use the visible warning state machine")
	random_steady_changer.configure(TrafficDirector.Kind.STEADY_SLOW, 1, 120.0)
	assert(not random_steady_changer.lane_change_enabled, "Object-pool reuse must clear a previous random lane-change plan")

	director.reset()
	director.random_lane_change_probability = 1.0
	var offscreen_random_changer = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, -120.0)
	director._plan_random_lane_change(offscreen_random_changer)
	director.vehicles.append(offscreen_random_changer)
	var original_random_lane_position: float = offscreen_random_changer.lane_position
	director.update_vehicle(offscreen_random_changer, 0.1, offscreen_random_changer.cruise_speed)
	assert(offscreen_random_changer.lane_change_enabled, "A guaranteed random lane-change plan must be created for the regression scenario")
	assert(not offscreen_random_changer.warning_started and not offscreen_random_changer.change_started, "Random lane changes must wait until the vehicle enters the visible area")
	assert(is_equal_approx(offscreen_random_changer.lane_position, original_random_lane_position), "Offscreen random lane-change plans must not move laterally")
	offscreen_random_changer.y = director._viewport_height + offscreen_random_changer.half_length
	director.update_vehicle(offscreen_random_changer, 0.1, offscreen_random_changer.cruise_speed)
	assert(not offscreen_random_changer.warning_started and not offscreen_random_changer.change_started, "Random lane changes must not begin after the vehicle has left the visible area")
	offscreen_random_changer.y = 80.0
	director.update_vehicle(offscreen_random_changer, 0.1, offscreen_random_changer.cruise_speed)
	assert(offscreen_random_changer.warning_started and offscreen_random_changer.warning_remaining > 0.0, "A visible random lane-change vehicle must show its turn signal before moving")
	assert(not offscreen_random_changer.change_started and is_equal_approx(offscreen_random_changer.lane_position, original_random_lane_position), "A random lane change must not move during its visible warning")
	director.update_vehicle(offscreen_random_changer, offscreen_random_changer.warning_remaining + 0.01, offscreen_random_changer.cruise_speed)
	assert(offscreen_random_changer.change_started and not is_equal_approx(offscreen_random_changer.lane_position, original_random_lane_position), "A random lane change may start inside the visible area only after its turn-signal warning completes")

	var overtaker = director.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 0, 820.0)
	director.update_vehicle(overtaker, 1.0, 760.0)
	assert(overtaker.overtake_warning_remaining >= 1.0, "Fast overtaker must warn for at least one visible second before collision risk")
	assert(director.is_fast_spawn_fair(760.0, 1), "Fast overtaker must use the player-speed reaction-distance fairness check")
	assert(TrafficDirector.fast_warning_y(700.0) >= 0.0 and TrafficDirector.fast_warning_y(700.0) <= 720.0, "Fast warning must be visible in the viewport")

	director.reset()
	var route_blocker = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 390.0)
	var route_overtaker = director.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 1, 700.0)
	route_blocker.spawn_was_fair = true
	route_overtaker.spawn_was_fair = true
	director.vehicles.assign([route_blocker, route_overtaker])
	director.update_vehicle(route_overtaker, 0.1, 760.0)
	assert(route_overtaker.lane_change_enabled, "Fast overtaker must plan a lane change when slower NPC traffic blocks its route")
	assert(abs(route_overtaker.target_lane - route_overtaker.lane) == 1, "Fast overtaker must select an adjacent overtaking lane")
	assert(route_overtaker.warning_remaining > 0.0, "Fast overtaker must signal before following its planned route")
	var starting_route_lane: int = route_overtaker.lane
	for _step in range(20):
		director.update_vehicle(route_overtaker, 0.1, 760.0)
	assert(route_overtaker.lane != starting_route_lane, "Fast overtaker must complete its planned lane change before passing the blocker")
	assert(route_overtaker.y < route_blocker.y, "Fast overtaker must continue past the NPC after changing to a clear lane")

	director.reset()
	var no_route_blocker = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, 390.0)
	var left_route_blocker = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, 690.0)
	var right_route_blocker = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 2, 690.0)
	var waiting_overtaker = director.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 1, 700.0)
	for vehicle in [no_route_blocker, left_route_blocker, right_route_blocker, waiting_overtaker]:
		vehicle.spawn_was_fair = true
	director.vehicles.assign([no_route_blocker, left_route_blocker, right_route_blocker, waiting_overtaker])
	director.update_vehicle(waiting_overtaker, 0.1, 760.0)
	var required_following_gap: float = director.minimum_lane_gap + waiting_overtaker.half_length + no_route_blocker.half_length
	assert(waiting_overtaker.y >= no_route_blocker.y + required_following_gap, "Fast overtaker must brake behind NPC traffic when no safe overtaking route exists")

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
	var stage_change_totals: Array[int] = []
	for stage in range(1, 4):
		var total_changes := 0
		for seed in range(1, 6):
			var measured = TrafficDirector.new(seed)
			measured.set_difficulty_stage(stage)
			for _tick in range(1200):
				measured.tick(0.1, 560.0, 1)
				assert(measured.all_active_spawns_are_fair(), "Every stage and seed must preserve active spawn fairness")
				assert(measured.vehicles.size() <= measured.max_active_vehicles and measured.allocated_vehicle_count <= measured.max_active_vehicles, "Every stage and seed must keep the active pool bounded")
			total_changes += measured.lane_change_started_count
		stage_change_totals.append(total_changes)
	assert(stage_change_totals[1] >= stage_change_totals[0], "Stage two must not reduce actual lane-change events")
	assert(stage_change_totals[2] > 0, "Stage three must still produce actual visible lane-change events despite denser traffic")

	director.reset()
	assert(director.vehicles.is_empty(), "Restart must clear actual active traffic")
	quit()
