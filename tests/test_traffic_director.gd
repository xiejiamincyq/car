extends SceneTree

const TrafficDirector = preload("res://scripts/traffic_director.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const TrackGeometry = preload("res://scripts/track_geometry.gd")

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
	assert(is_equal_approx(sedan_variant.y - initial_y, (500.0 - sedan_variant.cruise_speed) * GameConfig.ROAD_SCROLL_MULTIPLIER), "NPC screen motion must reflect player speed minus its road speed on the same world scale as the road")
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

	var committed_change = TrafficDirector.new(741)
	committed_change.set_viewport_height(720.0)
	committed_change._player_lane = 0
	committed_change._player_speed = 500.0
	var committed_changer = committed_change.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 1, 120.0, 200.0)
	committed_changer.target_lane = 0
	committed_change.vehicles.append(committed_changer)
	committed_change.update_vehicle(committed_changer, 0.1, 500.0)
	assert(committed_changer.warning_started, "A safe visible lane change must begin its warning")
	for _step in range(20):
		committed_change.update_vehicle(committed_changer, 0.05, 500.0)
		if committed_changer.change_started:
			break
	assert(committed_changer.change_started, "Once an NPC displays a lane-change arrow, it must honor that warning instead of cancelling the plan")

	var departing_change = TrafficDirector.new(742)
	departing_change.set_viewport_height(720.0)
	departing_change._player_lane = 1
	departing_change._player_speed = 0.0
	var departing_changer = departing_change.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, TrafficDirector.LANE_CHANGE_WARNING_ENTRY_Y, 200.0)
	departing_changer.target_lane = 1
	departing_change.vehicles.append(departing_changer)
	departing_change.update_vehicle(departing_changer, 0.1, 0.0)
	assert(not departing_changer.warning_started, "An NPC leaving the visible area before it can move must not display a false lane-change warning")

	var late_change = TrafficDirector.new(743)
	late_change.set_viewport_height(720.0)
	late_change._player_lane = 2
	late_change._player_speed = 550.0
	var late_changer = late_change.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 1, 340.0, 220.0)
	late_changer.target_lane = 2
	late_change.vehicles.append(late_changer)
	late_change.update_vehicle(late_changer, 0.1, 550.0)
	assert(not late_changer.warning_started, "A lane change that cannot finish warning before the immediate collision corridor must stay unannounced")

	var passed_change = TrafficDirector.new(744)
	passed_change.set_viewport_height(720.0)
	passed_change._player_lane = 2
	passed_change._player_speed = 180.0
	var passed_changer = passed_change.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 1, TrackGeometry.player_y(720.0) + 60.0, 220.0)
	passed_changer.target_lane = 2
	passed_change.vehicles.append(passed_changer)
	passed_change.update_vehicle(passed_changer, 0.1, 180.0)
	assert(not passed_changer.warning_started, "An NPC that the player has already passed must not begin a new lane-change warning behind them")
	var maximum_speed_timing = TrafficDirector.new(731)
	maximum_speed_timing.set_viewport_height(720.0)
	maximum_speed_timing._player_speed = GameConfig.MAX_SPEED
	var early_changer = maximum_speed_timing.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, TrafficDirector.LANE_CHANGE_WARNING_ENTRY_Y, TrafficDirector.NORMAL_SPEED_MIN)
	early_changer.target_lane = 1
	maximum_speed_timing.vehicles.append(early_changer)
	while not early_changer.change_started and early_changer.y < TrackGeometry.player_y(720.0):
		maximum_speed_timing.update_vehicle(early_changer, 0.02, GameConfig.MAX_SPEED)
	assert(early_changer.change_started, "A lane-changing NPC must begin moving before a maximum-speed player overtakes it")
	assert(early_changer.y < TrackGeometry.player_y(720.0) - GameConfig.COLLISION_LONGITUDINAL_DISTANCE, "The lane change must begin with visible reaction distance remaining at maximum player speed")
	var other_changer = director.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, 120.0)
	other_changer.target_lane = changer.target_lane
	other_changer.warning_started = true
	other_changer.warning_remaining = 0.5
	director.vehicles.append(other_changer)
	assert(not director.is_lane_change_safe(other_changer), "Two cars must not reserve the same merge lane")

	var coin_reserved_change = TrafficDirector.new(745)
	coin_reserved_change.set_viewport_height(720.0)
	coin_reserved_change._player_lane = 2
	coin_reserved_change._player_speed = 500.0
	var coin_blocked_changer = coin_reserved_change.acquire_vehicle(TrafficDirector.Kind.SIGNAL_CHANGE, 0, 160.0, 200.0)
	coin_blocked_changer.target_lane = 1
	coin_reserved_change.vehicles.append(coin_blocked_changer)
	coin_reserved_change.set_spawn_exclusion_zones([Vector2(1.0, 160.0)])
	coin_reserved_change.update_vehicle(coin_blocked_changer, 0.1, 500.0)
	assert(not coin_blocked_changer.warning_started, "An NPC must not announce or enter a lane change through an active coin guidance corridor")

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
	for _step in range(50):
		director.update_vehicle(route_overtaker, 0.1, 760.0)
		if route_overtaker.y < route_blocker.y:
			break
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

	var construction_route = TrafficDirector.new(407)
	construction_route.set_viewport_height(1080.0)
	construction_route._player_lane = 1
	construction_route._player_speed = 760.0
	construction_route.lane_events.begin_warning(0)
	var construction_player_y: float = construction_route.TrackGeometry.player_y(1080.0)
	var construction_taper_length: float = GameConfig.LANE_EVENT_TAPER_CONE_SPACING * float(GameConfig.LANE_EVENT_TAPER_CONE_COUNT - 1)
	var construction_core_distance: float = construction_player_y + GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN + construction_taper_length + GameConfig.LANE_EVENT_CORE_GAP
	construction_route.lane_events.tick(construction_core_distance / (GameConfig.START_SPEED * GameConfig.ROAD_SCROLL_MULTIPLIER), 3, 1, GameConfig.START_SPEED)
	var construction_overtaker = construction_route.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 2, 911.0)
	construction_route.vehicles.append(construction_overtaker)
	assert(not construction_route._fast_route_preserves_player_options(construction_overtaker, 1), "A fast overtaker must not claim the last escape lane beside an approaching construction core")

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
	assert(stage_change_totals[1] > 0, "Stage two must still produce actual visible lane changes after safety filtering")
	assert(stage_change_totals[2] > 0, "Stage three must still produce actual visible lane-change events despite denser traffic")

	director.reset()
	assert(director.vehicles.is_empty(), "Restart must clear actual active traffic")
	quit()
