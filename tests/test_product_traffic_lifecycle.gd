extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
const STEPS := [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.1, 0.25]
func _init() -> void:
	for delta in STEPS:
		if not _deadline(delta) or not _completion(delta):
			print("TEST_COMPLETE test_product_traffic_lifecycle.gd")
			quit(1)
			return
	print("TEST_COMPLETE test_product_traffic_lifecycle.gd")
	quit(0)

func _deadline(delta: float) -> bool:
	var traffic := Traffic.new(611)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 1, 1100.0, 920.0)
	vehicle.actual_world_speed = 0.0
	traffic.vehicles.append(vehicle)
	traffic._begin_fast_lane_change(vehicle, 0)
	var elapsed := 0.0
	while elapsed < 2.0 + delta + 0.00001:
		# Re-targeting an existing reservation must not buy another 2 seconds.
		traffic._begin_fast_lane_change(vehicle, 0 if int(elapsed / delta) % 2 == 0 else 2)
		traffic.tick(delta, 0.0, 1)
		elapsed += delta
		if not vehicle.warning_started:
			var okay: bool = elapsed <= 2.0 + delta + 0.00001 and vehicle.lane_change_cooldown > 0.0 and not vehicle.lane_change_reservation_active and not vehicle.change_started
			print("LIFECYCLE_DEADLINE ", JSON.stringify({"dt":delta,"elapsed":elapsed,"internal_age":vehicle.lane_change_wait_seconds,"cooldown":vehicle.lane_change_cooldown,"okay":okay}))
			return okay
	print("FAIL: screen-external renewed reservations exceeded the 2-second lifetime")
	return false

func _completion(delta: float) -> bool:
	var traffic := Traffic.new(2026)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, 350.0, 200.0)
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 1, 660.0, 920.0)
	vehicle.actual_world_speed = 200.0
	traffic.vehicles.assign([leader, vehicle])
	var warning_seen := false
	var started := false
	var visible_warning_seconds := 0.0
	for step in range(ceili(8.0 / delta)):
		var old_warning: bool = vehicle.warning_started and not vehicle.change_started
		var was_visible: bool = traffic._is_lane_change_visible(vehicle)
		traffic.tick(delta, 200.0, 2)
		warning_seen = warning_seen or vehicle.warning_started
		if old_warning and was_visible:
			visible_warning_seconds += delta
		if vehicle.last_lateral_distance > Traffic.FAST_LANE_CHANGE_SPEED * delta + 0.0001:
			print("FAIL: summed substep lateral path exceeded the one-frame budget")
			return false
		if vehicle.change_started:
			started = true
			if not traffic._is_lane_change_visible(vehicle) or visible_warning_seconds + delta < Traffic.FAST_ROUTE_WARNING_SECONDS:
				print("FAIL: actual lateral start requires complete visible warning")
				return false
		if started and not vehicle.change_started:
			var physical_completion: bool = absf(vehicle.lane_position - float(vehicle.target_lane)) <= 0.001 and vehicle.lane == vehicle.target_lane and not vehicle.lane_change_enabled
			print("LIFECYCLE_COMPLETION ", JSON.stringify({"dt":delta,"warning_seen":warning_seen,"visible_warning_seconds":visible_warning_seconds,"elapsed":(step+1)*delta,"physical_completion":physical_completion}))
			return warning_seen and physical_completion
	print("FAIL: valid already-braked queue must expose physical lane-change completion")
	return false
