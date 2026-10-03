extends SceneTree

const Recorder = preload("res://tests/support/observed_traffic.gd")
const Traffic = preload("res://scripts/traffic_director.gd")
var failures: Array[String] = []

# Deliberate test-only motion fault: two real internal steps cross another body,
# then return to the initial point. The outer-frame chord misses both crossings.
class CrossingTraffic extends Recorder:
	var forward := true
	func _advance_normal_vehicle(vehicle: TrafficVehicle, _delta: float, _player_speed: float) -> void:
		if vehicle.kind == Kind.STEADY_SLOW:
			vehicle.y = 100.0 if forward else -100.0
			forward = not forward
		else:
			vehicle.y = 0.0

func _init() -> void:
	var observed := Recorder.new(611)
	var plain := Traffic.new(611)
	for traffic in [observed,plain]:
		traffic.lane_events.enabled = false
		traffic._spawn_cooldown = 0.01
		traffic.tick(0.25,760.0,1)
	_check(observed.observed_steps == 15,"records all fifteen actual 250ms substeps")
	_check(observed.maximum_step <= 1.0/60.0,"records actual bounded delta")
	_check(observed.birth_count == plain.vehicles.size() and observed.birth_count > 0,"records admitted birth before its first movement")
	_check(observed.audit_issues.is_empty(),"legitimate production trajectory has no audit issues")
	_check(observed.spawn_sequence() == plain.spawn_sequence(),"observation does not change RNG or spawn sequence")
	_check(_motion_state(observed) == _motion_state(plain),"observation does not change motion")
	var retiring := Recorder.new(2026)
	retiring.lane_events.enabled = false
	retiring._spawn_cooldown = 1000.0
	var vehicle = retiring.acquire_vehicle(Traffic.Kind.STEADY_SLOW,1,710.0,200.0)
	retiring.vehicles.append(vehicle)
	retiring.tick(1.0/60.0,10000.0,1)
	_check(retiring.retirement_count == 1 and retiring.vehicles.is_empty(),"records actual recycle rather than missing old reference")
	_check(not retiring.last_retired.is_empty() and float(retiring.last_retired.get("y",0.0)) > 860.0,"captures final coordinate before pool reuse")
	_check(retiring.audit_issues.is_empty(),"visible before step but offscreen at actual retirement is valid")
	var crossing := CrossingTraffic.new(9001)
	crossing.lane_events.enabled = false
	crossing._spawn_cooldown = 1000.0
	crossing.vehicles.append(crossing.acquire_vehicle(Traffic.Kind.STEADY_SLOW,1,-100.0,200.0))
	var stationary = crossing.acquire_vehicle(Traffic.Kind.SIGNAL_CHANGE,1,0.0,200.0)
	stationary.lane_change_enabled = false
	crossing.vehicles.append(stationary)
	crossing.tick(1.0/30.0,200.0,1)
	_check(crossing.vehicles[0].y == -100.0,"fault fixture returns to original outer-frame coordinate")
	_check(absf(crossing.vehicles[0].y-stationary.y) > crossing.vehicles[0].half_length+stationary.half_length,"outer-frame endpoints are genuinely separated bodies")
	_check(crossing.audit_issues.filter(func(issue): return issue.begins_with("sweep_overlap:")).size() == 2,"both interior step crossings are independently detected")
	for step in 40: crossing.tick(1.0/30.0,200.0,1)
	_check(crossing.audit_issues.size() <= 64,"failure detail buffer remains bounded")
	_check(crossing.issue_counts.get("sweep_overlap",0) == 82,"bounded buffer does not discard actual failure counts")
	_check(not crossing.first_issue_snapshot.is_empty(),"first failure retains raw start/end lifecycle evidence")
	for failure in failures: push_error("OBSERVER_SELF_CHECK "+failure)
	print("OBSERVER_SELF_CHECK failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_traffic_observer.gd")
	quit(0 if failures.is_empty() else 1)

func _motion_state(traffic) -> Array:
	var result: Array = []
	for vehicle in traffic.vehicles:
		result.append([vehicle.kind,vehicle.lane,vehicle.lane_position,vehicle.y,vehicle.actual_world_speed,vehicle.cruise_speed])
	return result

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
