extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const STEP := 1.0 / 60.0

func _init() -> void:
	var traffic := Traffic.new(611)
	traffic.set_viewport_height(720.0)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	var fast = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 600.0, 920.0)
	fast.actual_world_speed = 200.0
	# Below the visible-turn boundary, the leader cannot actively yield yet.
	# This still exposes a genuine red-car route warning under RC4 priority.
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 20.0, 200.0)
	var target_leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, -300.0, 200.0)
	traffic.vehicles.assign([fast, leader, target_leader])
	traffic.tick(STEP, 200.0, 1)
	var warning_observed: bool = fast.warning_started and fast.lane_change_enabled
	var warning_resets := 0
	for step in range(480):
		var old_warning: float = fast.warning_remaining
		traffic.tick(STEP, 200.0, 1)
		if fast.warning_remaining > old_warning:
			warning_resets += 1
		if warning_observed and (not fast.lane_change_enabled or not is_zero_approx(fast.lane_position)):
			print("FAST_WARNING_EVIDENCE ", JSON.stringify({"seconds":(step + 2) * STEP, "warning_observed":true, "resolved":true, "resets":warning_resets, "lane_position":fast.lane_position}))
			_finish(true)
			return
	print("FAST_WARNING_EVIDENCE ", JSON.stringify({"seconds":8.0 + STEP, "warning_observed":warning_observed, "resolved":false, "resets":warning_resets, "lane_position":fast.lane_position, "fast_y":fast.y, "target_leader_y":target_leader.y}))
	_finish(false)

func _finish(passed: bool) -> void:
	if not passed:
		print("FAIL: a fast-car route warning must start or clearly cancel, not reset forever against an unchanged slower target leader")
	print("TEST_COMPLETE test_product_traffic_fast_warning.gd")
	quit(0 if passed else 1)
