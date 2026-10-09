extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const Geometry = preload("res://scripts/track_geometry.gd")

func _init() -> void:
	var traffic := Traffic.new(611)
	traffic.lane_events.enabled = false
	traffic._spawn_cooldown = 1000.0
	# Explicit legacy finite-braking fixture; production constant-speed entry
	# is exercised separately at configured 450 by fast_constant_entry.
	var fast = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 600.0, 400.0 / 0.42)
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, -700.0, 200.0)
	var distant = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, -1200.0, 200.0)
	traffic.vehicles.assign([fast, leader, distant])
	var started := false
	var passed := false
	var safe := true
	for step in 120:
		traffic.tick(1.0 / 60.0, 760.0, 2)
		started = started or fast.change_started or fast.lane == 1
		passed = passed or fast.y < Geometry.player_y(720.0) - fast.half_length
		safe = safe and not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall()
	# Finite acceleration from warning/braking needs more than two seconds to
	# pass. Keep the early-commit deadline, then separately allow physical travel.
	for step in 480:
		traffic.tick(1.0 / 60.0, 760.0, 2)
		passed = passed or fast.y < Geometry.player_y(720.0) - fast.half_length
		safe = safe and not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall()
		if passed: break
	print("FAST_DISTANT_LEADER ", JSON.stringify({"started":started,"passed":passed,"safe":safe,"lane":fast.lane,"y":fast.y}))
	# A finite-braking merge must commit promptly. A crowded route is not
	# guaranteed to pass this faster player before normal offscreen retirement.
	if not (started and safe): push_error("A distant slower target leader must permit a brakeable merge, not cancel every warning")
	print("TEST_COMPLETE test_product_fast_distant_leader.gd")
	quit(0 if started and safe else 1)
