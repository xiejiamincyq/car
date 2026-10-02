extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	var forward := _sample(false)
	var reverse := _sample(true)
	var okay: bool = forward == reverse
	print("SPAWN_ORDER ", JSON.stringify({"forward":forward,"reverse":reverse,"okay":okay}))
	print("TEST_COMPLETE test_product_traffic_spawn_order.gd")
	quit(0 if okay else 1)

func _sample(reversed: bool) -> Dictionary:
	var traffic := Traffic.new(417)
	traffic.lane_events.enabled = false
	traffic._spawn_cooldown = 1000.0
	var ahead = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, -1100.0, 180.0)
	var behind = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, -100.0, 220.0)
	traffic.vehicles.assign([behind, ahead] if reversed else [ahead, behind])
	var desired := traffic._world_speed_for_spawn(Traffic.Kind.STEADY_SLOW, 1, -620.0)
	var candidate = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, -620.0, desired)
	var admitted := traffic._can_spawn_candidate(candidate, 200.0, 1)
	traffic.vehicles.append(candidate)
	for step in range(120):
		traffic.tick(1.0 / 60.0, 200.0, 1)
	return {"desired":desired,"admitted":admitted,"final_y":candidate.y,"final_actual":candidate.actual_world_speed}
