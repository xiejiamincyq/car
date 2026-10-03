extends SceneTree
## A new slow car must not appear inside an existing fast car's stopping path.
## Coordinates/speeds are from natural Main failures, no player-speed exemption.
const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
var failures: Array[String] = []

func _init() -> void:
	for player_speed in [0.0, 200.0, 604.8, 760.0]:
		for kind in [Traffic.Kind.STEADY_SLOW, Traffic.Kind.SIGNAL_CHANGE, Traffic.Kind.TRUCK]:
			var traffic := Traffic.new(9001)
			traffic.lane_events.enabled = false
			traffic._spawn_cooldown = 1000.0
			var fast = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 2, 103.246922466003, 920.0)
			traffic.vehicles.append(fast)
			var leader_speed := 176.0 if kind == Traffic.Kind.TRUCK else 220.0
			var leader = traffic.acquire_vehicle(kind, 2, -620.0, leader_speed)
			var accepted := traffic._can_spawn_candidate(leader, player_speed, 0)
			_check(not accepted, "Slow offscreen spawn ahead of 920-speed traffic must be rejected, speed=%s kind=%s" % [player_speed, kind])
			leader.y = -2000.0
			_check(traffic._can_spawn_candidate(leader, player_speed, 0), "A genuinely brakeable distant spawn remains allowed")
	# Admission in the opposite direction also protects a new fast follower.
	var traffic := Traffic.new(611)
	traffic.lane_events.enabled = false
	var normal = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 2, -620.0, 220.0)
	traffic.vehicles.append(normal)
	var fast = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 2, 103.246922466003, 920.0)
	_check(not traffic._can_spawn_candidate(fast, 604.8, 0), "Unbraked fast candidate cannot use a kind-specific admission exemption")
	fast.actual_world_speed = 220.0
	_check(traffic._can_spawn_candidate(fast, 604.8, 0), "Fast spawn with a safe actual initial speed remains allowed")
	# Independent numeric budget: body separation excludes both car lengths;
	# stopping distance accounts for both speeds, finite braking and road scale.
	var gap: float = 723.246922466003 - 84.0
	var stopping: float = ((920.0 * 920.0 - 220.0 * 220.0) / (2.0 * 420.0) + (920.0 - 220.0) * 0.25) * Config.ROAD_SCROLL_MULTIPLIER
	_check(gap < stopping, "Recorded natural fixture cannot be rescued by immediate finite braking")
	print("FAST_SPAWN_GAP_SELF_CHECK ", JSON.stringify({"failures": failures.size(), "body_gap": gap, "stopping_budget": stopping}))
	for failure in failures: push_error(failure)
	print("TEST_COMPLETE test_product_traffic_fast_spawn_gap.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
