extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	for single_lane in [false, true]:
		for kind in ["fuel", "repair", "none"]:
			for full_frame in [false, true]:
				if kind == "none" and not full_frame:
					continue
				_prepare(main, kind, single_lane)
				var event = main.traffic.lane_events
				var before: Array = event.cone_markers(720.0)
				var closed_before: Array = event.closed_lanes()
				_check(before.size() >= 5, "%s fixture has a visibly established cone section" % kind)
				var reward_before: float = main.run.fuel if kind == "fuel" else main.integrity.current
				if full_frame:
					main._process(0.0)
				else:
					main.call("_update_fuel_pickups" if kind == "fuel" else "_update_repair_pickups", 0.0)
				var reward_after: float = main.run.fuel if kind == "fuel" else main.integrity.current
				var remaining: int = main.fuel_pickups.size() if kind == "fuel" else main.repair_supplies.pickups.size()
				if kind != "none":
					_check(reward_after > reward_before and remaining == 0, "%s is genuinely collected via %s" % [kind, "Main frame" if full_frame else "supply update"])
				else:
					_check(reward_after == reward_before, "no-supply control awards no repair")
				print("SUPPLY_CONSTRUCTION_EVIDENCE ", JSON.stringify({"single_lane_with_npc":single_lane,"kind":kind,"full_frame":full_frame,"cones_before":before.size(),"cones_after":event.cone_markers(720.0).size(),"state":event.state,"reward_before":reward_before,"reward_after":reward_after,"history":event.event_history()}))
				_check(event.state == main.LaneEventDirector.State.WARNING and event.closed_lanes() == closed_before and event.cone_markers(720.0) == before, "%s must not erase established world-fixed construction via %s, single_lane=%s" % [kind, "Main frame" if full_frame else "supply update", single_lane])
	var refs: Array[WeakRef] = AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, refs), "audio teardown completes")
	for failure in failures:
		push_error("SUPPLY_PRESERVES_CONSTRUCTION " + failure)
	print("SUPPLY_PRESERVES_CONSTRUCTION failures=%d" % failures.size())
	print("TEST_COMPLETE test_supply_preserves_construction.gd")
	quit(0 if failures.is_empty() else 1)

func _prepare(main, kind: String, single_lane: bool) -> void:
	main._reset_run(9001)
	main.run.start()
	main.run.distance = 1200.0
	main.run.progression.observe(main.run.distance)
	main.run.fuel = 40.0
	main.integrity.current = 40.0
	main.drive.speed = 200.0
	# A previously published two-lane event is still upstream of the player.
	# The driver has crossed leftward to a supply left over from before closure.
	# There is no cone/core collision and no completed event-tail retirement.
	main.drive.lateral_position = -main.GameConfig.ROAD_HALF_WIDTH * 2.0 / main.GameConfig.ROAD_LANE_COUNT
	main.traffic._spawn_cooldown = 1000.0
	var closed_lanes: Array[int] = []
	closed_lanes.assign([0] if single_lane else [0, 1])
	main.traffic.lane_events.begin_warning_lanes(closed_lanes)
	main.traffic.lane_events._travel_distance = 500.0 if single_lane else 850.0
	main.traffic.set_viewport_height(720.0)
	if single_lane:
		# The adjacent NPC is alongside, not touching the player, cones or core.
		main.traffic.vehicles.append(main.traffic.acquire_vehicle(main.TrafficDirector.Kind.STEADY_SLOW, 1, main.TrackGeometry.player_y(720.0), 200.0))
	main.fuel_spawn_director.spawn_remaining = 1000.0
	main.repair_supplies.spawner.spawn_remaining = 1000.0
	var pickup = main.FuelPickup.new(0, main.TrackGeometry.player_y(720.0))
	if kind == "fuel":
		main.fuel_pickups.append(pickup)
	elif kind == "repair":
		main.repair_supplies.pickups.append(pickup)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
