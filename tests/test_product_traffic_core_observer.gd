extends SceneTree
const Recorder = preload("res://tests/support/observed_core_traffic.gd")
const Traffic = preload("res://scripts/traffic_director.gd")
const Events = preload("res://scripts/lane_event_director.gd")
const RecordedEvents = preload("res://tests/support/observed_lane_events.gd")
var failures: Array[String] = []
var checks := 0

class Controlled extends Recorder:
	var cancel_at := 0
	var closure_calls := 0
	var end_y := 70.0
	var force_birth := false
	func _closure_can_continue() -> bool:
		closure_calls += 1
		return closure_calls != cancel_at
	func _advance_normal_vehicle(vehicle: TrafficVehicle, _delta: float, _speed: float) -> void:
		vehicle.y = end_y
	func _spawn_next(_speed: float, _lane: int) -> void:
		if not force_birth: return
		var vehicle = acquire_vehicle(Kind.STEADY_SLOW,1,-30.0,200.0)
		vehicle.lane_change_enabled = false
		vehicles.append(vehicle)
		# This fixture supplies an actual admitted birth boundary to the parent
		# recorder, without pretending production spawn policy admitted this body.
		var bodies := _snapshot()
		for key in bodies:
			_step_births[key] = bodies[key]

class PingPong extends Controlled:
	var forward := true
	func _advance_normal_vehicle(vehicle: TrafficVehicle, _delta: float, _speed: float) -> void:
		vehicle.y = 70.0 if forward else -130.0
		forward = not forward

class MissingFinalEvents extends RecordedEvents:
	func _retire(_bodies: Dictionary, _reason: String) -> void:
		pass

class InvalidBirthEvents extends RecordedEvents:
	func raw_cores() -> Dictionary:
		var bodies := super.raw_cores()
		for body in bodies.values(): body.half_x = -1.0
		return bodies

class MovedRollbackEvents extends RecordedEvents:
	func _retire(bodies: Dictionary, reason: String) -> void:
		var final := bodies.duplicate(true)
		for body in final.values(): body.y += 1.0
		super._retire(final,reason)

func _init() -> void:
	var observed := Recorder.new(611)
	var plain := Traffic.new(611)
	for traffic in [observed,plain]:
		traffic.set_difficulty_stage(3)
		traffic.lane_events._cooldown_remaining = 0.0
		traffic._spawn_cooldown = 0.01
		traffic.tick(0.25,760.0,1)
	_check(observed.core_steps == 15,"captures every real internal step")
	_check(observed.core_birth_count > 0,"captures actual scheduled core births")
	_check(observed.spawn_sequence() == plain.spawn_sequence(),"does not change traffic RNG")
	_check(observed.lane_events.event_history() == plain.lane_events.event_history(),"does not change event RNG")
	_check(_motion(observed) == _motion(plain),"does not change real NPC motion")
	_check(observed.core_issues.is_empty(),"natural initial trajectory remains clear")
	for phase in [1,2,3]:
		var controlled := _fixture(phase)
		controlled.tick(1.0/60.0,0.0,2)
		_check(controlled.core_retirement_count == 1,"records cancellation at phase %d" % phase)
		if phase < 3:
			_check(controlled.core_issues.is_empty(),"does not invent post-cancellation contact at phase %d" % phase)
		else:
			_check(controlled.core_issue_counts.get("core_sweep_overlap",0) == 1,"retains actual crossing before late cancellation")
		_check(not controlled.last_core_step.is_empty(),"retains phase witness at cancellation %d" % phase)
	var crossing := _fixture(0)
	crossing.tick(1.0/60.0,0.0,2)
	_check(crossing.core_issue_counts.get("core_sweep_overlap",0) == 1,"detects live core interior crossing with clear endpoints")
	_check(not crossing.first_core_issue.is_empty(),"first contact retains raw phase evidence")
	var born := _fixture(0,false)
	born.force_birth = true
	born.end_y = -130.0
	born._spawn_cooldown = 0.0
	born.tick(1.0/60.0,10000.0,2)
	_check(born.vehicles.size() == 1,"new NPC actually exists after spawn hook")
	_check(born.core_issues.is_empty(),"new NPC is not retroactively present during prebirth core advance")
	var ended := _fixture(0)
	ended.lane_events.state = Events.State.CLOSED
	ended.lane_events._travel_distance += 840.0-ended.lane_events._event_tail_y()-0.1
	ended.tick(1.0/60.0,20.0,2)
	_check(ended.core_retirement_count == 1,"records final core coordinate at natural end")
	_check(ended.core_issues.is_empty(),"does not invent post-end core existence")
	_check(ended.last_core_step.core_final.values()[0].y > 1000.0,"retains final actual advanced coordinate rather than pre-advance body")
	var repeated := PingPong.new(2026)
	_setup(repeated,true)
	repeated.tick(1.0/30.0,0.0,2)
	_check(repeated.vehicles[0].y == -130.0,"two internal faults return to clear outer endpoint")
	_check(repeated.core_issue_counts.get("core_sweep_overlap",0) == 2,"both internal crossings survive an outer clear chord")
	for step in 40: repeated.tick(1.0/30.0,0.0,2)
	_check(repeated.core_issues.size() == 64,"core failure detail buffer is bounded")
	_check(repeated.core_issue_counts.get("core_sweep_overlap",0) == 82,"bounded buffer retains full contact counts")
	var missing := Controlled.new(2026)
	missing.lane_events = MissingFinalEvents.new(2026)
	_setup(missing,true)
	missing.cancel_at = 1
	missing.tick(1.0/60.0,0.0,2)
	_check(missing.core_issue_counts.get("core_unobserved_lifetime",0) == 1,"unexplained core disappearance fails rather than passing")
	# A scheduled proposal is born and rolled back synchronously before the
	# first NPC update. It was never published as a live world obstacle.
	var aborted := _scheduled_birth(1)
	aborted.tick(1.0/60.0,0.0,0)
	_check(aborted.core_birth_count == 1 and aborted.core_retirement_count == 1,"retains rejected scheduled proposal evidence")
	_check(aborted.core_issues.is_empty(),"atomic pre-motion birth rollback is not a physical contact")
	_check(aborted.get("aborted_core_birth_count") == 1,"reports atomic rollback separately rather than hiding birth and retirement")
	var published := _scheduled_birth(2)
	published.tick(1.0/60.0,0.0,0)
	_check(published.core_issue_counts.get("core_initial_overlap",0) == 1,"a newborn core that reaches NPC motion still detects initial contact")
	var existing_overlap := _fixture(1)
	existing_overlap.vehicles[0].y = -30.0
	existing_overlap.tick(1.0/60.0,0.0,2)
	_check(existing_overlap.core_issue_counts.get("core_initial_overlap",0) == 1,"preexisting core contact is not waived by early cancellation")
	var invalid_birth := _scheduled_birth(1)
	invalid_birth.lane_events = InvalidBirthEvents.new(2026)
	invalid_birth.lane_events._cooldown_remaining = 0.0
	invalid_birth.tick(1.0/60.0,0.0,0)
	_check(invalid_birth.core_issue_counts.get("core_invalid_snapshot",0) == 1,"invalid rolled-back geometry remains a failure")
	var moved_birth := _scheduled_birth(1)
	moved_birth.lane_events = MovedRollbackEvents.new(2026)
	moved_birth.lane_events._cooldown_remaining = 0.0
	moved_birth.tick(1.0/60.0,0.0,0)
	_check(moved_birth.core_issue_counts.get("core_sweep_overlap",0) == 1,"a birth with actual travel before cancellation is not an atomic rollback")
	for failure in failures: push_error("CORE_OBSERVER_SELF_CHECK "+failure)
	print("CORE_OBSERVER_SELF_CHECK checks=%d failures=%d" % [checks,failures.size()])
	print("TEST_COMPLETE test_product_traffic_core_observer.gd")
	quit(0 if failures.is_empty() else 1)

func _fixture(cancel_at: int, with_npc: bool = true) -> Controlled:
	var traffic := Controlled.new(2026)
	_setup(traffic,with_npc)
	traffic.cancel_at = cancel_at
	return traffic

func _scheduled_birth(cancel_at: int) -> Controlled:
	var traffic := Controlled.new(2026)
	traffic.set_difficulty_stage(3)
	traffic.lane_events.configure_double_lane_probability(0.0)
	traffic.lane_events._cooldown_remaining = 0.0
	traffic._spawn_cooldown = 1000.0
	traffic.cancel_at = cancel_at
	traffic.end_y = -584.58
	var vehicle = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW,2,-584.58,200.0)
	vehicle.lane_change_enabled = false
	traffic.vehicles.append(vehicle)
	return traffic

func _setup(traffic, with_npc: bool) -> void:
	traffic.set_difficulty_stage(3)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.begin_warning(1)
	# Remain before the genuine WARNING -> CLOSED travel boundary.
	traffic.lane_events._travel_distance += -30.0-traffic.lane_events._core_y()
	if with_npc:
		var vehicle = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW,1,-130.0,200.0)
		vehicle.lane_change_enabled = false
		traffic.vehicles.append(vehicle)

func _motion(traffic) -> Array:
	var result: Array = []
	for vehicle in traffic.vehicles:
		result.append([vehicle.kind,vehicle.lane_position,vehicle.y,vehicle.actual_world_speed])
	return result

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
