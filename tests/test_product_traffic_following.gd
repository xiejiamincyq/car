extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const STEP := 1.0 / 60.0

func _init() -> void:
	var traffic := Traffic.new(616)
	traffic.set_viewport_height(720.0)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	var follower = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 0.0, 220.0)
	var truck = traffic.acquire_vehicle(Traffic.Kind.TRUCK, 0, -620.0, 144.0)
	traffic.vehicles.append(follower)
	# Record the old spawn predicate, but test ongoing safety independently of it.
	var initially_accepted := traffic._can_spawn_candidate(truck, 760.0, 1)
	traffic.vehicles.append(truck)
	var speed := 760.0
	var smallest_gap := INF
	for step in range(480):
		speed = move_toward(speed, 220.0, Config.BRAKING * STEP)
		traffic.tick(STEP, speed, 1)
		var body_gap: float = absf(follower.y - truck.y) - follower.half_length - truck.half_length
		smallest_gap = minf(smallest_gap, body_gap)
		if body_gap < 0.0 and absf(follower.lane_position - truck.lane_position) < 0.1:
			print("FOLLOWING_EVIDENCE ", JSON.stringify({"seed":616, "seconds":(step + 1) * STEP, "spawn_accepted":initially_accepted, "player_speed":speed, "follower_y":follower.y, "truck_y":truck.y, "net_body_gap":body_gap}))
			print("FAIL: braking after an accepted slow-truck spawn must not cause an NPC body overlap")
			print("TEST_COMPLETE test_product_traffic_following.gd")
			quit(1)
			return
	print("FOLLOWING_EVIDENCE ", JSON.stringify({"seed":616, "seconds":8.0, "spawn_accepted":initially_accepted, "smallest_net_body_gap":smallest_gap}))
	print("TEST_COMPLETE test_product_traffic_following.gd")
	quit(0)
