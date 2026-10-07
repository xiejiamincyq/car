extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
var failures: Array[String] = []
class FastOnly extends Traffic:
	func _kind_for_next_spawn() -> int: return Kind.FAST_OVERTAKE

func _init() -> void:
	var traffic := FastOnly.new(611)
	traffic.lane_events.enabled = false
	traffic._player_speed = 760.0
	traffic._player_lane = 1
	traffic.vehicles.append(traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 400.0, 200.0))
	traffic._spawn_next(760.0, 1)
	var fast = null
	for vehicle in traffic.vehicles:
		if vehicle.kind == Traffic.Kind.FAST_OVERTAKE: fast = vehicle
	_check(fast != null and fast.lane == 2, "Fast birth must select the clear side instead of joining the occupied preferred lane")
	traffic = FastOnly.new(611)
	traffic.lane_events.enabled = false
	traffic._spawn_cooldown = 1000.0
	fast = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 600.0)
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, -700.0, 200.0)
	traffic.vehicles.assign([fast, leader])
	traffic.tick(1.0 / 60.0, 760.0, 1)
	_check(fast.lane_change_enabled, "Plan before a distant slower leader forces braking, not only within 620px")
	var passed := false
	for step in 600:
		traffic.tick(1.0 / 60.0, 760.0, 1)
		_check(not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall(), "Early planning retains traffic safety")
		if fast.y < Geometry.player_y(720.0) - fast.half_length: passed = true
	_check(passed, "A viable route completes the pass instead of escorting the player indefinitely")
	for failure in failures: push_error(failure)
	print("TEST_COMPLETE test_product_fast_encounter.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
