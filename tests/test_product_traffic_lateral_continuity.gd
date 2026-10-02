extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const STEP := 1.0 / 60.0

func _init() -> void:
	var traffic := Traffic.new(2026)
	traffic.set_viewport_height(720.0)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	var fast = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 600.0, 920.0)
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 200.0, 200.0)
	traffic.vehicles.assign([fast, leader])
	var moving_exposure := false
	for step in range(180):
		traffic.tick(STEP, 200.0, 1)
		if fast.change_started and fast.lane_position >= 0.5 and fast.lane_position < 0.9:
			moving_exposure = true
			break
	if not moving_exposure:
		print("FAIL: fixture did not reach the required naturally started half-complete lane change")
		_finish(false)
		return
	# The player's adjacent lane change removes the previously available escape
	# option. The NPC must resolve this continuously, not snap to a lane center.
	var previous_position: float = fast.lane_position
	traffic.tick(STEP, 200.0, 0)
	var displacement: float = absf(fast.lane_position - previous_position)
	var allowed_step := Traffic.FAST_LANE_CHANGE_SPEED * STEP
	print("LATERAL_CONTINUITY_EVIDENCE ", JSON.stringify({"seed":2026, "exposure":moving_exposure, "before":previous_position, "after":fast.lane_position, "delta_lanes":displacement, "allowed_delta_lanes":allowed_step}))
	if displacement > allowed_step + 0.00001:
		print("FAIL: loss of player escape options must not teleport an already-turning NPC")
	_finish(displacement <= allowed_step + 0.00001)

func _finish(passed: bool) -> void:
	print("TEST_COMPLETE test_product_traffic_lateral_continuity.gd")
	quit(0 if passed else 1)
