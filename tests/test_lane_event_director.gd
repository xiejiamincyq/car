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
	assert(first.event_history() == second.event_history() and not first.event_history().is_empty(), "A fixed seed must reproduce the same closure timing and lanes")

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
		if traffic.lane_events.blocked_lane() >= 0:
			assert(not traffic.reachable_player_lanes(1, 620.0, 72.0).has(0), "Navigation must not advertise a warned or closed lane as an escape route")
	assert(traffic.lane_events.blocked_lane() == -1, "The lane must safely return after the event ends")

	var barrier := LaneEventDirector.new(99, GameConfig.ROAD_LANE_COUNT, true)
	barrier.begin_warning(1)
	assert(is_equal_approx(barrier.constrain_lateral_position(0.0, 30.0, GameConfig.ROAD_HALF_WIDTH), 0.0), "A warning must leave the lane physically open during the reaction window")
	barrier.state = LaneEventDirector.State.CLOSED
	var projected_from_center: float = barrier.constrain_lateral_position(0.0, 30.0, GameConfig.ROAD_HALF_WIDTH)
	assert(absf(projected_from_center) >= 160.0, "A closed center lane must project the whole player car into an open lane")
	assert(is_equal_approx(barrier.constrain_lateral_position(-220.0, 30.0, GameConfig.ROAD_HALF_WIDTH), -220.0), "A player already outside the closed lane must not be moved")
	barrier.lane = 0
	assert(is_equal_approx(barrier.constrain_lateral_position(-300.0, 30.0, GameConfig.ROAD_HALF_WIDTH), -100.0), "A closed edge lane must push the player toward the remaining road")
	quit()
