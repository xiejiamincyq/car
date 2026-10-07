extends SceneTree
const Recorder = preload("res://tests/support/observed_change_traffic.gd")
const Traffic = preload("res://scripts/traffic_director.gd")
const DT := 1.0/60.0
const Difficulty = preload("res://scripts/difficulty_profile.gd")
var failures: Array[String] = []
var checks := 0

class EarlyWarning extends Recorder:
	func lane_change_warning_duration() -> float:
		return 0.01

class OffscreenWarning extends EarlyWarning:
	func _is_lane_change_visible(_vehicle: TrafficVehicle) -> bool:
		return true
	func _lane_change_starts_while_visible(_vehicle: TrafficVehicle) -> bool:
		return true

class IncompleteChange extends Recorder:
	func _complete_normal_lane_change(vehicle: TrafficVehicle) -> void:
		# A deliberately faulty completion with cleared flags at a partial body
		# position, not a mere incomplete label on a physically finished vehicle.
		super._complete_normal_lane_change(vehicle)
		vehicle.lane_position -= 0.1

class EndlessWarning extends Recorder:
	func _update_lane_change_lifecycle(vehicle: TrafficVehicle, delta: float) -> void:
		vehicle.lane_change_cooldown = maxf(0.0,vehicle.lane_change_cooldown-delta)
	func _advance_fast_lane_change(_vehicle: TrafficVehicle, _delta: float) -> void:
		pass

class LateLateral extends Recorder:
	func _advance_normal_vehicle(vehicle: TrafficVehicle, delta: float, speed: float) -> void:
		super._advance_normal_vehicle(vehicle,delta,speed)
		vehicle.lane_position += 0.01

class LegalCancellation extends Recorder:
	var allow_warning := true
	func _lane_change_warning_preserves_immediate_player_options(_vehicle: TrafficVehicle) -> bool:
		return allow_warning

func _init() -> void:
	var normal := Recorder.new(611)
	var plain := Traffic.new(611)
	for traffic in [normal,plain]: _normal(traffic,100.0)
	for step in 80:
		normal.tick(DT,200.0,2)
		plain.tick(DT,200.0,2)
	_check(normal.warnings_observed == 1 and normal.starts_observed == 1 and normal.completions_observed == 1,"real normal warning starts and physically completes once")
	_check(normal.change_issues.is_empty(),"full visible normal warning is legal")
	for difficulty_index in range(3):
		var configured := Recorder.new(611)
		configured.configure_difficulty(Difficulty.for_index(difficulty_index))
		_normal(configured,100.0)
		for step in 100: configured.tick(DT,200.0,2)
		_check(configured.change_issues.is_empty() and configured.completions_observed == 1,"configured difficulty observes its full warning independently %d" % difficulty_index)
		var configured_early := EarlyWarning.new(611)
		configured_early.configure_difficulty(Difficulty.for_index(difficulty_index))
		_normal(configured_early,100.0)
		for step in 10: configured_early.tick(DT,200.0,2)
		_check(configured_early.change_issue_counts.get("incomplete_visible_warning",0) > 0,"difficulty cannot hide deliberately early production warning %d" % difficulty_index)
	_check(_motion(normal) == _motion(plain),"lifecycle observation preserves actual production trajectory")
	var fast := Recorder.new(2026)
	_fast(fast)
	for step in 180: fast.tick(DT,200.0,2)
	_check(fast.warnings_observed > 0 and fast.starts_observed > 0 and fast.completions_observed > 0,"natural already-braked fast queue warns and completes")
	_check(fast.change_issues.is_empty(),"full fast warning and actual physical completion are legal")
	var early := EarlyWarning.new(611)
	_normal(early,100.0)
	for step in 10: early.tick(DT,200.0,2)
	_check(early.change_issue_counts.get("incomplete_visible_warning",0) > 0,"production timer spoof cannot replace observed full visible warning")
	var offscreen := OffscreenWarning.new(611)
	_normal(offscreen,-10.0)
	for step in 10: offscreen.tick(DT,200.0,2)
	_check(offscreen.change_issue_counts.get("offscreen_warning",0) > 0,"oracle does not trust production visibility helper")
	_check(offscreen.change_issue_counts.get("offscreen_start",0) > 0,"actual offscreen lateral start is rejected")
	var incomplete := IncompleteChange.new(611)
	_normal(incomplete,100.0)
	for step in 80: incomplete.tick(DT,200.0,2)
	_check(incomplete.change_issue_counts.get("incomplete_physical_change",0) > 0,"clearing flags at a partial lateral position is not completion")
	var endless := EndlessWarning.new(2026)
	_fast(endless)
	for step in 220:
		if step > 0: endless._begin_fast_lane_change(endless.vehicles[1],0 if step%2 == 0 else 2)
		endless.tick(DT,200.0,2)
	_check(endless.change_issue_counts.get("reservation_deadline",0) > 0,"one original reservation cannot wait forever")
	_check(not endless.first_change_issue.is_empty(),"retains independent elapsed and raw warning state")
	_check(endless.change_issues.size() == 64 and endless.change_issue_counts.get("reservation_deadline",0) > 64,"bounded lifecycle details preserve full deadline failure count")
	var retry := Recorder.new(2026)
	_fast(retry)
	retry.tick(DT,200.0,2)
	var retry_fast = retry.vehicles[1]
	retry._cancel_planned_lane_change(retry_fast)
	retry._begin_fast_lane_change(retry_fast,0)
	_check(retry.change_issue_counts.get("early_reservation_retry",0) == 1,"a genuine release does not permit immediate renewed reservation")
	var unknown := Recorder.new(611)
	_normal(unknown,100.0)
	unknown.vehicles[0].warning_started = true
	unknown.vehicles[0].lane_change_reservation_active = true
	unknown.vehicles[0].warning_remaining = 0.62
	unknown.tick(DT,200.0,2)
	_check(unknown.change_issue_counts.get("missing_warning_evidence",0) == 1,"an injected already-on indicator cannot invent earlier warning exposure")
	var late := LateLateral.new(611)
	_normal(late,100.0)
	late.tick(DT,200.0,2)
	_check(late.change_issue_counts.get("lateral_outside_behavior",0) == 1,"legal-size hidden sideways motion after the decision hook is still rejected")
	var cancelled := LegalCancellation.new(611)
	_normal(cancelled,100.0)
	cancelled.tick(DT,200.0,2)
	cancelled.allow_warning = false
	cancelled.tick(DT,200.0,2)
	_check(cancelled.cancellations_observed == 1 and not cancelled.vehicles[0].warning_started,"actual unsafe pending intent legally cancels")
	_check(cancelled.change_issues.is_empty(),"a cancellation in the behavior hook does not erase previously observed warning evidence")
	for failure in failures: push_error("CHANGE_OBSERVER_SELF_CHECK "+failure)
	print("CHANGE_OBSERVER_SELF_CHECK checks=%d failures=%d" % [checks,failures.size()])
	print("TEST_COMPLETE test_product_traffic_change_observer.gd")
	quit(0 if failures.is_empty() else 1)

func _normal(traffic, y: float) -> void:
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	traffic.set_difficulty_stage(1)
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.SIGNAL_CHANGE,0,y,200.0)
	vehicle.target_lane = 1
	traffic.vehicles.append(vehicle)

func _fast(traffic) -> void:
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	traffic.set_difficulty_stage(3)
	traffic.vehicles.append(traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW,1,350.0,200.0))
	var fast = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE,1,660.0,920.0)
	fast.actual_world_speed = 200.0
	traffic.vehicles.append(fast)

func _motion(traffic) -> Array:
	var result: Array = []
	for vehicle in traffic.vehicles:
		result.append([vehicle.lane_position,vehicle.y,vehicle.actual_world_speed,vehicle.warning_remaining,vehicle.change_started])
	return result

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
