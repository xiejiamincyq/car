extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
func _init() -> void:
	var positive := _impact(100.0)
	var negative := _impact(-100.0)
	var core := _core_snapshot()
	var passed := positive and negative and core
	print("TEST_COMPLETE test_product_traffic_frame_safety.gd")
	quit(0 if passed else 1)

func _impact(offset: float) -> bool:
	var traffic := Traffic.new(17)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 300.0, 200.0)
	vehicle.impact_speed_offset = offset
	traffic.vehicles.append(vehicle)
	for step in range(60):
		traffic.tick(1.0 / 60.0, 200.0, 1)
		if vehicle.actual_world_speed < 0.0 or vehicle.actual_world_speed > 300.0001:
			print("FAIL: impact may not compound or reverse absolute NPC speed ", JSON.stringify({"offset":offset,"step":step,"actual":vehicle.actual_world_speed}))
			return false
	return true

func _core_snapshot() -> bool:
	var traffic := Traffic.new(9001)
	traffic._spawn_cooldown = 1000.0
	traffic.set_difficulty_stage(1)
	traffic.lane_events.begin_warning(0)
	traffic.lane_events.state = traffic.LaneEventDirector.State.CLOSED
	traffic.lane_events._travel_distance += 100.0 - traffic.lane_events._core_y()
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 210.0, 200.0)
	# A physically recoverable queue state: desired stays 200, but it already
	# braked to actual 150. At 200 this 48px net gap cannot stop with finite 420
	# braking, so that state would not be a valid no-contact expectation.
	vehicle.actual_world_speed = 150.0
	traffic.vehicles.append(vehicle)
	traffic.tick(0.25, 760.0, 2)
	var gap: float = vehicle.y - traffic.lane_events._core_y()
	print("CORE_SNAPSHOT_EVIDENCE ", JSON.stringify({"dt":0.25,"gap":gap,"speed":vehicle.actual_world_speed}))
	if gap < 62.0:
		print("FAIL: NPC/core positions must share a time snapshot")
		return false
	return true
