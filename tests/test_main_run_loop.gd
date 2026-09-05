extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const Main = preload("res://scripts/main.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(Main.is_eligible_overtake(TrafficDirector.Kind.STEADY_SLOW, true, false), "A normal vehicle that truly passes must score")
	assert(not Main.is_eligible_overtake(TrafficDirector.Kind.FAST_OVERTAKE, true, false), "Rear overtakers must never earn a front-pass reward")
	assert(not Main.is_eligible_overtake(TrafficDirector.Kind.STEADY_SLOW, false, false), "A vehicle must be observed ahead before it can score")
	assert(not Main.is_eligible_overtake(TrafficDirector.Kind.STEADY_SLOW, true, true), "A collision-displaced vehicle must not score")
	var main = MainScene.instantiate()
	root.add_child(main)
	main.run.start()
	main.run.elapsed_seconds = 29.9
	main.run.fuel = 0.0
	main.collision.invulnerability_remaining = 0.5
	main._process(0.2)
	assert(main.run.phase == main.RunState.Phase.ENDED, "The fuel-ending frame must enter settlement immediately")
	assert(main.traffic.vehicles.is_empty(), "Traffic may not advance or spawn after the ending transition")
	assert(main.fuel_pickups.is_empty(), "Pickups may not advance or spawn after the ending transition")
	assert(is_equal_approx(main.collision.invulnerability_remaining, 0.5), "Collision timers may not advance after the ending transition")
	main.free()

	var cleared_main = MainScene.instantiate()
	root.add_child(cleared_main)
	cleared_main.run.start()
	cleared_main.run.distance = cleared_main.GameConfig.RACE_FINISH_DISTANCE - 1.0
	cleared_main.collision.invulnerability_remaining = 0.5
	cleared_main._process(0.1)
	assert(cleared_main.run.phase == cleared_main.RunState.Phase.RUN_CLEAR, "The finish frame must enter settlement immediately")
	assert(cleared_main.traffic.vehicles.is_empty(), "Traffic may not advance or spawn after the clear transition")
	assert(is_equal_approx(cleared_main.collision.invulnerability_remaining, 0.5), "Collision timers may not advance after the clear transition")
	cleared_main.free()

	var event_main = MainScene.instantiate()
	root.add_child(event_main)
	event_main.run.start()
	event_main.traffic.lane_events.begin_warning(0)
	event_main._update_hud()
	assert(event_main.feedback_banner.visible and "前方施工 · 向右并线" in event_main.feedback_banner.text, "A construction warning must state the safe merge direction")
	assert(event_main._construction_arrow_lane([0]) == 0, "A left-lane closure arrow must start inside the closed lane and point right toward open traffic")
	assert(event_main._construction_arrow_lane([2]) == 2, "A right-lane closure arrow must start inside the closed lane and point left toward open traffic")
	assert(event_main._construction_arrow_lane([0, 1]) == 1 and event_main._construction_arrow_lane([1, 2]) == 1, "A double-closure arrow must occupy the closed lane adjacent to the sole open lane")
	event_main.traffic.lane_events.state = event_main.LaneEventDirector.State.CLOSED
	event_main._update_hud()
	assert("施工路段 · 右侧通行" in event_main.feedback_banner.text, "An active construction zone must state the open side")
	event_main.drive.lateral_position = -300.0
	event_main._process(0.0)
	assert(is_equal_approx(event_main.drive.lateral_position, -300.0), "A construction closure must never force the player sideways")
	event_main.traffic.lane_events.begin_warning(0)
	var player_y: float = event_main.TrackGeometry.player_y(event_main.get_viewport_rect().size.y)
	var taper_length: float = event_main.GameConfig.LANE_EVENT_TAPER_CONE_SPACING * float(event_main.GameConfig.LANE_EVENT_TAPER_CONE_COUNT - 1)
	var cone_target_distance: float = player_y + event_main.GameConfig.LANE_EVENT_CORE_TRAVEL_MARGIN + taper_length
	event_main.traffic.lane_events.tick(cone_target_distance / (event_main.GameConfig.START_SPEED * event_main.GameConfig.ROAD_SCROLL_MULTIPLIER), 2, 1, event_main.GameConfig.START_SPEED)
	event_main.drive.lateral_position = -130.0
	var speed_before_cone: float = event_main.drive.speed
	event_main._check_construction_collisions()
	assert(event_main.drive.speed <= speed_before_cone and event_main.drive.speed >= speed_before_cone * 0.99, "Lightweight cones must cause only a small impulse")
	assert(event_main.integrity.current >= 98.0 and event_main.knocked_cones.size() == 1, "A cone must be knocked away with at most two points of damage")
	event_main.free()

	var track_main = MainScene.instantiate()
	root.add_child(track_main)
	track_main.save_data.tour.selected_track_id = &"storm_ridge"
	track_main._start_new_run()
	assert(track_main.current_track.id == &"storm_ridge", "Starting from the map must apply the selected track")
	assert(is_equal_approx(track_main.run.progression.finish_distance, 3300.0), "The selected track must replace the default race distance")
	assert(track_main.traffic.track_pattern == &"ridge_weave", "The selected track must replace the traffic identity")
	assert(track_main.current_environment_left[0].resource_path.ends_with("storm_ridge/left_00.png") and track_main.current_environment_left.size() == 5, "The selected track must load its full ordered left scenery sequence")
	assert(track_main.current_environment_right[0].resource_path.ends_with("storm_ridge/right_00.png") and track_main.current_environment_right.size() == 5, "The selected track must load its full ordered right scenery sequence")
	track_main.free()
	quit()
