extends SceneTree

const GameConfig = preload("res://scripts/game_config.gd")
const LaneEventDirector = preload("res://scripts/lane_event_director.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	var lane_width := GameConfig.ROAD_HALF_WIDTH * 2.0 / GameConfig.ROAD_LANE_COUNT
	var minimum_warning := lane_width / GameConfig.STEERING_SPEED + 0.1
	assert(GameConfig.LANE_EVENT_WARNING_SECONDS >= minimum_warning, "Closure warning must exceed one full lane-change time plus reaction margin")

	var disabled := LaneEventDirector.new(41, GameConfig.ROAD_LANE_COUNT, false)
	for _second in range(120):
		disabled.tick(1.0, 3, 1)
	assert(disabled.event_history().is_empty(), "The centralized toggle must fully disable lane events")

	var first := LaneEventDirector.new(73, GameConfig.ROAD_LANE_COUNT, true)
	var second := LaneEventDirector.new(73, GameConfig.ROAD_LANE_COUNT, true)
	for _step in range(240):
		first.tick(0.25, 3, 1, 560.0)
		second.tick(0.25, 3, 1, 560.0)
		if first.blocked_lane() >= 0:
			assert(first.blocked_lane() != 1, "A new closure may not suddenly target the player's occupied lane")
			assert(first.blocked_lane() == 0 or first.blocked_lane() == GameConfig.ROAD_LANE_COUNT - 1, "A single construction diversion must close an outside lane for a readable merge")
	assert(first.event_history() == second.event_history() and not first.event_history().is_empty(), "A fixed seed must reproduce the same closure timing and lanes")

	var guided_closure := LaneEventDirector.new(74, GameConfig.ROAD_LANE_COUNT, true)
	guided_closure.set_guidance_reserved_lanes([0])
	guided_closure.tick(120.0, 2, 1, 560.0)
	assert(guided_closure.state == LaneEventDirector.State.WARNING and not guided_closure.closed_lanes().has(0), "A scheduled closure must preserve the active coin route destination lane")
	var fully_reserved := LaneEventDirector.new(75, GameConfig.ROAD_LANE_COUNT, true)
	fully_reserved.set_guidance_reserved_lanes([0, 2])
	fully_reserved.tick(120.0, 2, 1, 560.0)
	assert(fully_reserved.state == LaneEventDirector.State.IDLE, "A construction event must wait when every readable outside lane is reserved by the player and coin guidance")

	var construction := LaneEventDirector.new(131, GameConfig.ROAD_LANE_COUNT, true)
	construction.begin_warning(0)
	assert(construction.closed_lanes() == [0], "A single construction event must expose its complete closed-lane set")
	construction.tick(GameConfig.LANE_EVENT_WARNING_SECONDS * 0.5, 2, 1, GameConfig.START_SPEED)
	var warning_cones: Array[Dictionary] = construction.cone_markers(720.0)
	assert(not warning_cones.is_empty(), "The warning phase must expose visible taper-cone geometry")
	var first_encountered_cone: Dictionary = warning_cones[0]
	for cone in warning_cones:
		if float(cone.y) > float(first_encountered_cone.y):
			first_encountered_cone = cone
	assert(is_equal_approx(float(first_encountered_cone.lane_position), 0.0), "A left-lane taper must begin at the closed road edge before narrowing toward the open-lane boundary")
	var warning_geometry := construction.cone_markers(720.0)
	construction.state = LaneEventDirector.State.CLOSED
	assert(construction.cone_markers(720.0) == warning_geometry, "Changing construction phase must not replace or teleport road-fixed cones")
	construction.state = LaneEventDirector.State.WARNING
	assert(construction.lanes_blocked_near(592.0, 72.0, 720.0).is_empty(), "Breakable warning cones must not turn the whole lane into a navigation exclusion zone")
	assert(construction.navigation_blocked_lanes(592.0, 72.0, 720.0) == [0], "The warning must reserve the planned construction lane for route selection before the solid core arrives")
	var first_cone_id: int = int(warning_cones[0].id)
	assert(construction.consume_cone(first_cone_id), "The first player contact must knock a taper cone away")
	assert(not construction.consume_cone(first_cone_id), "A knocked cone must not apply collision twice")

	var right_taper := LaneEventDirector.new(133, GameConfig.ROAD_LANE_COUNT, true)
	right_taper.begin_warning(GameConfig.ROAD_LANE_COUNT - 1)
	right_taper.tick(GameConfig.LANE_EVENT_WARNING_SECONDS * 0.5, 2, 1, GameConfig.START_SPEED)
	var right_cones := right_taper.cone_markers(720.0)
	var right_first_encountered: Dictionary = right_cones[0]
	for cone in right_cones:
		if float(cone.y) > float(right_first_encountered.y):
			right_first_encountered = cone
	assert(is_equal_approx(float(right_first_encountered.lane_position), float(GameConfig.ROAD_LANE_COUNT)), "A right-lane taper must begin at the right road edge before narrowing toward the open-lane boundary")

	var continuous_segment := LaneEventDirector.new(134, GameConfig.ROAD_LANE_COUNT, true)
	continuous_segment.set_viewport_height(1400.0)
	continuous_segment.begin_warning(0)
	continuous_segment.tick(1000.0 / (GameConfig.START_SPEED * GameConfig.ROAD_SCROLL_MULTIPLIER), 2, 1, GameConfig.START_SPEED)
	var full_segment := continuous_segment.cone_markers(1400.0)
	assert(full_segment.size() == GameConfig.LANE_EVENT_TAPER_CONE_COUNT + GameConfig.LANE_EVENT_STRAIGHT_CONE_COUNT, "The taper and straight construction boundary must coexist as one complete segment")
	for index in range(1, full_segment.size()):
		assert(is_equal_approx(float(full_segment[index - 1].y) - float(full_segment[index].y), GameConfig.LANE_EVENT_TAPER_CONE_SPACING), "Every adjacent construction cone must keep one continuous road-space spacing across the taper boundary")

	var road_fixed := TrafficDirector.new(132)
	road_fixed.set_viewport_height(720.0)
	road_fixed.set_difficulty_stage(2)
	road_fixed.lane_events.begin_warning(0)
	road_fixed.tick(0.5, 560.0, 1)
	var moving_cones := road_fixed.lane_events.cone_markers(720.0)
	assert(not moving_cones.is_empty(), "A moving construction segment must enter the viewport")
	var moving_y := float(moving_cones[0].y)
	road_fixed.tick(0.25, 560.0, 1)
	var advanced_cones := road_fixed.lane_events.cone_markers(720.0)
	assert(is_equal_approx(float(advanced_cones[0].y) - moving_y, 560.0 * GameConfig.ROAD_SCROLL_MULTIPLIER * 0.25), "Construction cones must move by the same road-relative distance as lane markings")
	var stopped_y := float(advanced_cones[0].y)
	road_fixed.tick(0.5, 0.0, 1)
	assert(is_equal_approx(float(road_fixed.lane_events.cone_markers(720.0)[0].y), stopped_y), "Construction cones must remain fixed to the ground while the player is stopped")

	construction.tick(GameConfig.LANE_EVENT_WARNING_SECONDS, 2, 1, GameConfig.START_SPEED)
	assert(construction.state == LaneEventDirector.State.CLOSED, "The construction core must follow the taper warning")
	assert(construction.core_markers(720.0).size() == 1, "A single-lane closure must expose one solid construction core obstacle")
	var core_y_before := construction.core_markers(720.0)[0].y
	construction.tick((592.0 - core_y_before) / (GameConfig.START_SPEED * GameConfig.ROAD_SCROLL_MULTIPLIER), 2, 1, GameConfig.START_SPEED)
	assert(construction.lanes_blocked_near(592.0, 72.0, 720.0) == [0], "Only a solid construction core near the queried position may block its lane")

	var hard_edge := LaneEventDirector.new(811, GameConfig.ROAD_LANE_COUNT, true)
	hard_edge.configure_double_lane_probability(1.0)
	hard_edge.tick(120.0, 3, 0)
	assert(hard_edge.closed_lanes() == [1, 2], "A hard-mode double closure must leave the player's outside lane fully open")
	assert(hard_edge.state_remaining >= GameConfig.LANE_EVENT_DOUBLE_WARNING_SECONDS, "A double closure must provide the longer warning window")
	var hard_center := LaneEventDirector.new(812, GameConfig.ROAD_LANE_COUNT, true)
	hard_center.configure_double_lane_probability(1.0)
	hard_center.tick(120.0, 3, 1)
	assert(hard_center.closed_lanes().size() == 1, "A centered player must force a double closure to fall back to a safe single-lane event")
	var bounded_events := LaneEventDirector.new(901, GameConfig.ROAD_LANE_COUNT, true)
	bounded_events.configure_double_lane_probability(1.0)
	for _step in range(600):
		bounded_events.tick(0.25, 3, 0, 560.0)
	assert(bounded_events.events_started_count >= 2 and bounded_events.events_started_count <= 4, "A full run must bound construction events to two through four starts")
	assert(bounded_events.double_lane_events_started <= 1, "Hard mode may schedule at most one double-lane closure per run")

	var traffic := TrafficDirector.new(501)
	traffic.set_difficulty_stage(2)
	var conflict = traffic.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 0, 200.0)
	conflict.spawn_was_fair = true
	traffic.vehicles.append(conflict)
	traffic.lane_events.begin_warning(0)
	traffic.tick(0.0, 560.0, 1)
	assert(traffic.vehicles.size() == 1, "A closure warning must preserve existing NPCs instead of making them disappear")
	assert(traffic.lane_events.blocked_lane() == 0, "The warned lane must be reserved immediately")
	traffic.tick(0.5, 200.0, 1)
	assert(traffic.vehicles.has(conflict) and conflict.lane == 0, "Pre-existing traffic may visibly drive out through the warned lane")
	for _step in range(25):
		traffic.tick(0.25, 560.0, 1)
		for vehicle in traffic.vehicles:
			if vehicle != conflict and traffic.lane_events.is_lane_blocked(0):
				assert(vehicle.lane != 0, "No new vehicle may spawn into a warned or closed lane")
		for physically_blocked_lane in traffic.lane_events.lanes_blocked_near(620.0, 72.0, 720.0):
			assert(not traffic.reachable_player_lanes(1, 620.0, 72.0).has(physically_blocked_lane), "Navigation must not advertise a nearby solid construction core as an escape route")
	assert(traffic.lane_events.blocked_lane() == -1, "The lane must safely return after the event ends")

	var barrier := LaneEventDirector.new(99, GameConfig.ROAD_LANE_COUNT, true)
	barrier.begin_warning(1)
	assert(is_equal_approx(barrier.constrain_lateral_position(0.0, 30.0, GameConfig.ROAD_HALF_WIDTH), 0.0), "A warning must leave the lane physically open during the reaction window")
	barrier.state = LaneEventDirector.State.CLOSED
	assert(is_equal_approx(barrier.constrain_lateral_position(0.0, 30.0, GameConfig.ROAD_HALF_WIDTH), 0.0), "A construction closure must never seize steering control or project the player sideways")
	assert(is_equal_approx(barrier.constrain_lateral_position(-220.0, 30.0, GameConfig.ROAD_HALF_WIDTH), -220.0), "A player already outside the closed lane must not be moved")
	barrier.lane = 0
	assert(is_equal_approx(barrier.constrain_lateral_position(-300.0, 30.0, GameConfig.ROAD_HALF_WIDTH), -300.0), "An edge-lane construction closure must still leave steering entirely under player control")
	quit()
