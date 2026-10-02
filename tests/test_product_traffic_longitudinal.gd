extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const STEPS := [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.1, 0.25]

func _init() -> void:
	for delta in STEPS:
		for reversed_order in [false, true]:
			if not _following(delta, reversed_order) or not _construction(delta, reversed_order):
				quit(1)
				return
	print("TEST_COMPLETE test_product_traffic_longitudinal.gd")
	quit(0)

func _following(delta: float, reversed_order: bool) -> bool:
	var traffic := Traffic.new(616)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	var follower = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 0.0, 220.0)
	var leader = traffic.acquire_vehicle(Traffic.Kind.TRUCK, 0, -620.0, 144.0)
	traffic.vehicles.assign([leader, follower] if reversed_order else [follower, leader])
	var minimum_gap := INF
	var reduced := false
	var player_speed := 760.0
	for step in range(ceili(8.0 / delta)):
		player_speed = move_toward(player_speed, 220.0, Config.BRAKING * delta)
		var before: float = follower.actual_world_speed
		traffic.tick(delta, player_speed, 1)
		var gap: float = follower.y - leader.y - follower.half_length - leader.half_length
		minimum_gap = minf(minimum_gap, gap)
		reduced = reduced or follower.actual_world_speed < 219.0
		if gap < 0.0 or follower.actual_world_speed < -0.0001 or absf(follower.actual_world_speed - before) > Traffic.NPC_BRAKING * delta + 0.0001:
			print("FAIL: independent body gap or finite longitudinal speed change; dt=", delta, " gap=", gap)
			return false
	if not reduced or not is_equal_approx(follower.cruise_speed, 220.0):
		print("FAIL: following must reduce actual speed without rewriting desired speed")
		return false
	traffic.vehicles.erase(leader)
	for step in range(ceili(2.0 / delta)):
		traffic.tick(delta, 220.0, 1)
	if not is_equal_approx(follower.actual_world_speed, 220.0):
		print("FAIL: clear road must restore assigned cruise speed")
		return false
	print("LONGITUDINAL_MATRIX ", JSON.stringify({"dt":delta,"reversed_order":reversed_order,"minimum_gap":minimum_gap,"recovered_speed":follower.actual_world_speed}))
	return true

func _construction(delta: float, reversed_order: bool) -> bool:
	var traffic := Traffic.new(9001)
	traffic.set_difficulty_stage(1)
	traffic._spawn_cooldown = 1000.0
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 200.0, 200.0)
	var follower = traffic.acquire_vehicle(Traffic.Kind.TRUCK, 0, 600.0, 144.0)
	traffic.vehicles.assign([follower, leader] if reversed_order else [leader, follower])
	traffic.lane_events.begin_warning(0)
	var slowed := false
	var stopped := false
	for step in range(ceili(6.0 / delta)):
		traffic.tick(delta, 180.0, 2)
		slowed = slowed or leader.actual_world_speed < 199.0
		stopped = stopped or leader.actual_world_speed < 1.0
		for vehicle in [leader, follower]:
			for core in traffic.lane_events.core_markers(720.0):
				if absf(vehicle.y - core.y) < maxf(62.0, vehicle.half_length + 20.0):
					print("FAIL: queue body entered solid core; dt=", delta)
					return false
		if leader.y >= 0.0 and leader.y <= 720.0 and not traffic.vehicles.has(leader):
			print("FAIL: visible queued NPC was removed")
			return false
	if not slowed or not stopped:
		print("FAIL: core must expose finite braking and waiting; dt=", delta)
		return false
	return true
