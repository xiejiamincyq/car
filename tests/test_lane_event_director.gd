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
		first.tick(0.25, 3, 1)
		second.tick(0.25, 3, 1)
		if first.blocked_lane() >= 0:
			assert(first.blocked_lane() != 1, "A new closure may not suddenly target the player's occupied lane")
			assert(first.blocked_lane() == 0 or first.blocked_lane() == GameConfig.ROAD_LANE_COUNT - 1, "A single construction diversion must close an outside lane for a readable merge")
	assert(first.event_history() == second.event_history() and not first.event_history().is_empty(), "A fixed seed must reproduce the same closure timing and lanes")

	var construction := LaneEventDirector.new(131, GameConfig.ROAD_LANE_COUNT, true)
	construction.begin_warning(0)
	assert(construction.closed_lanes() == [0], "A single construction event must expose its complete closed-lane set")
	construction.tick(GameConfig.LANE_EVENT_WARNING_SECONDS * 0.5, 2, 1)
	var warning_cones: Array[Dictionary] = construction.cone_markers(720.0)
	assert(not warning_cones.is_empty(), "The warning phase must expose visible taper-cone geometry")
	assert(construction.lanes_blocked_near(592.0, 72.0, 720.0).is_empty(), "Breakable warning cones must not turn the whole lane into a navigation exclusion zone")
	assert(construction.navigation_blocked_lanes(592.0, 72.0, 720.0) == [0], "The warning must reserve the planned construction lane for route selection before the solid core arrives")
	var first_cone_id: int = int(warning_cones[0].id)
	assert(construction.consume_cone(first_cone_id), "The first player contact must knock a taper cone away")
	assert(not construction.consume_cone(first_cone_id), "A knocked cone must not apply collision twice")
	construction.tick(GameConfig.LANE_EVENT_WARNING_SECONDS, 2, 1)
	assert(construction.state == LaneEventDirector.State.CLOSED, "The construction core must follow the taper warning")
	assert(construction.core_markers(720.0).size() == 1, "A single-lane closure must expose one solid construction core obstacle")
	construction.state_remaining = 1.0
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
		bounded_events.tick(0.25, 3, 0)
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
			if vehicle != conflict:
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
