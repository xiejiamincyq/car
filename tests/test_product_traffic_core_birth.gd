extends SceneTree
const Observed = preload("res://tests/support/observed_change_traffic.gd")
const Config = preload("res://scripts/game_config.gd")
const Events = preload("res://scripts/lane_event_director.gd")
const STEP := 1.0/60.0
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	for kind in 4:
		var half_length := 74.0 if kind == 3 else 42.0
		for offset in [-half_length-34.0+0.001,-half_length-34.0+4.0,-48.353541666662]:
			var traffic = _fixture(kind,offset)
			var vehicle = traffic.vehicles[0]
			var before_y: float = vehicle.y
			traffic.tick(STEP,75.75,0)
			_check(traffic.lane_events.state == Events.State.IDLE,"scheduled core overlapping kind%d at offset%.6f must roll back" % [kind,offset])
			_check(traffic.core_issue_counts.is_empty(),"scheduled body overlap must never reach actual NPC movement")
			_check(traffic.aborted_core_birth_count == 1,"unsafe scheduled core remains recorded as an atomic rollback")
			# A fast-car fixture this far above the viewport legitimately exits
			# through the unchanged pool policy; do not call that a repair delete.
			_check(traffic.vehicles.has(vehicle) or (kind == 2 and traffic.retirement_count == 1 and vehicle.y+vehicle.half_length < 0.0),"NPC retained or accounted for by genuine fast-car offscreen retirement")
			_check(absf(vehicle.y-before_y-(75.75-vehicle.actual_world_speed)*Config.ROAD_SCROLL_MULTIPLIER*STEP) < 0.00000001,"NPC retains physical motion without relocation")
	for kind in 4:
		var half_length := 74.0 if kind == 3 else 42.0
		for offset in [-half_length-34.0,-half_length-34.0-0.001,-500.0,5000.0]:
			var traffic = _fixture(kind,offset)
			traffic.lane_events.begin_warning(2)
			_check(traffic._closure_can_continue(),"clear/tangent core proposal preserves admission for kind%d at offset%.3f" % [kind,offset])
	var adjacent = _fixture(0,-48.0)
	adjacent.vehicles[0].lane_position = 1.0
	adjacent.lane_events.begin_warning(2)
	_check(adjacent._closure_can_continue(),"other-lane NPC does not unnecessarily suppress a core")
	for kind in 4:
		for delta in [1.0/30.0,1.0/60.0,1.0/120.0,0.1,0.25]:
			for speed in [0.0,75.75,469.3,1000.0]:
				var traffic = _fixture(kind,-48.0)
				traffic.tick(delta,speed,0)
				_check(traffic.lane_events.state == Events.State.IDLE,"body-safe birth cancellation at kind%d dt%.6f speed%.2f" % [kind,delta,speed])
				_check(traffic.core_issue_counts.is_empty() and traffic.motion_issue_counts.is_empty() and traffic.issue_counts.is_empty(),"all actual substeps remain geometrically and physically legal")
				_check(traffic.aborted_core_birth_count == 1,"exactly one proposal rollback through unusual outer frames")
	for kind in [0,3]:
		for clearance in [-0.0001,0.0001]:
			var traffic = _fixture(kind,-48.0)
			var lane_width := Config.ROAD_HALF_WIDTH*2.0/3.0
			var body_width: float = traffic.vehicles[0].half_width+lane_width*Config.LANE_EVENT_CORE_HALF_LANE_RATIO
			traffic.vehicles[0].lane_position = 2.0-(body_width+clearance)/lane_width
			traffic.lane_events.begin_warning(2)
			_check(traffic._closure_can_continue() == (clearance > 0.0),"fractional-lane body edge has the correct geometric admission boundary")
	for kind in [0,3]:
		for occupied_lane in [1,2]:
			var traffic = _fixture(kind,-48.0)
			traffic.set_difficulty_stage(3)
			traffic.lane_events.configure_double_lane_probability(1.0)
			traffic.lane_events._warning_duration = Config.LANE_EVENT_DOUBLE_WARNING_SECONDS
			traffic.vehicles[0].y = traffic.lane_events._core_y()-48.0
			traffic.vehicles[0].lane = occupied_lane
			traffic.vehicles[0].lane_position = float(occupied_lane)
			traffic.tick(STEP,75.75,0)
			_check(traffic.lane_events.state == Events.State.IDLE,"one occupied core cancels both lanes of a scheduled double closure")
			_check(traffic.aborted_core_birth_count == 2,"both double-closure bodies retain their atomic rollback record")
			_check(traffic.core_issue_counts.is_empty(),"double closure cannot enter movement with overlapping NPC")
	for failure in failures: push_error("CORE_BIRTH_SELF_CHECK "+failure)
	print("CORE_BIRTH_SELF_CHECK checks=%d failures=%d" % [checks,failures.size()])
	print("TEST_COMPLETE test_product_traffic_core_birth.gd")
	quit(0 if failures.is_empty() else 1)

func _fixture(kind: int, offset: float):
	var traffic = Observed.new(2026)
	traffic.set_difficulty_stage(1)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events._cooldown_remaining = 0.0
	# Single scheduled closure is forced away from player lane0 into lane2 by
	# the actual production candidate rule, not a synthetic published core.
	var vehicle = traffic.acquire_vehicle(kind,2,-660.0+offset,200.0)
	vehicle.lane_change_enabled = false
	traffic.vehicles.append(vehicle)
	return traffic

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
