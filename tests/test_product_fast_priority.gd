extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Events = preload("res://scripts/lane_event_director.gd")
const STEP := 1.0 / 60.0
const PLAYER_SPEED := 200.0
var failures: Array[String] = []

# Only the random birth schedule is fixed; every decision and motion step is real.
class ObservedTraffic extends Traffic:
	var physical_failures: Array[String] = []
	var visible_warning_seconds: Dictionary = {}
	var warning_before_motion: Dictionary = {}
	func _kind_for_next_spawn() -> int:
		return Kind.STEADY_SLOW
	func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
		var before: Dictionary = {}
		for actor in vehicles:
			var key := "%d:%d" % [actor.get_instance_id(), actor.motion_generation]
			before[key] = {"y":actor.y,"position":actor.lane_position,"speed":actor.actual_world_speed}
			if actor.warning_started and actor.y >= LANE_CHANGE_WARNING_ENTRY_Y and actor.y <= _viewport_height - actor.half_length:
				visible_warning_seconds[key] = float(visible_warning_seconds.get(key, 0.0)) + delta
		super._tick_step(delta, player_speed, player_lane, frame_start)
		for actor in vehicles:
			var key := "%d:%d" % [actor.get_instance_id(), actor.motion_generation]
			if not before.has(key):
				continue
			var old: Dictionary = before[key]
			var rate: float = 420.0 if actor.actual_world_speed < old.speed else (360.0 if actor.kind == Kind.FAST_OVERTAKE else 140.0)
			if absf(actor.actual_world_speed - old.speed) > rate * delta + 0.00001:
				_record("finite acceleration/braking")
			var expected_y: float = old.y + (player_speed - actor.actual_world_speed) * Config.ROAD_SCROLL_MULTIPLIER * delta
			if absf(actor.y - expected_y) > 0.00001:
				_record("continuous longitudinal movement, no staging teleport")
			var lateral_limit: float = FAST_LANE_CHANGE_SPEED if actor.kind == Kind.FAST_OVERTAKE else NORMAL_LANE_CHANGE_SPEED
			if absf(actor.lane_position - old.position) > lateral_limit * delta + 0.00001:
				_record("continuous lateral movement, no instant yielding")
			if absf(actor.lane_position - old.position) > 0.00001 and not warning_before_motion.has(key):
				warning_before_motion[key] = float(visible_warning_seconds.get(key, 0.0))
				var minimum_warning: float = FAST_ROUTE_WARNING_SECONDS if actor.kind == Kind.FAST_OVERTAKE else lane_change_warning_duration()
				if warning_before_motion[key] < minimum_warning - STEP - 0.00001:
					_record("visible turn warning before lateral movement")
		if has_vehicle_overlap():
			_record("no physical NPC body overlap")
		if has_full_lane_wall():
			_record("preserve wall120 escape safety")
	func _record(message: String) -> void:
		if not physical_failures.has(message):
			physical_failures.append(message)

func _init() -> void:
	_test_visible_leader_yields_and_fast_passes_promptly()
	_test_unstarted_normal_merge_does_not_claim_fast_corridor()
	_test_new_births_pause_and_resume_after_natural_pass()
	_test_new_construction_pauses()
	_test_published_construction_is_not_erased_or_frozen()
	for failure in failures:
		push_error("FAST_PRIORITY " + failure)
	print("FAST_PRIORITY failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_fast_priority.gd")
	quit(0 if failures.is_empty() else 1)

func _fixture(seed_value: int = 611) -> ObservedTraffic:
	var traffic := ObservedTraffic.new(seed_value)
	traffic.set_viewport_height(720.0)
	traffic.lane_events.enabled = false
	traffic._spawn_cooldown = 1000.0
	return traffic

func _red(traffic: ObservedTraffic, lane_value: int = 0, initial_y: float = 650.0):
	var actor = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, lane_value, initial_y, 920.0)
	# A braked arrival is a valid initial state, not an impossible full-speed
	# birth 450px behind a 200-speed leader (which needs >1600px to brake).
	# Matching the player's speed leaves no initial closing speed during the
	# visible arrival warning; acceleration/braking starts only through tick.
	actor.actual_world_speed = PLAYER_SPEED
	traffic.vehicles.append(actor)
	return actor

func _test_visible_leader_yields_and_fast_passes_promptly() -> void:
	var traffic := _fixture()
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 200.0, 200.0)
	traffic.vehicles.append(leader)
	var red = _red(traffic)
	_check(traffic.vehicles_keep_safe_gap_until_recycle(leader, red, PLAYER_SPEED), "yield fixture has an initially brakeable longitudinal gap")
	var yielded_at := -1.0
	var passed_leader_at := -1.0
	var passed_player_at := -1.0
	var arrival_warning_seen := false
	for step in 240:
		traffic.tick(STEP, PLAYER_SPEED, 2)
		var elapsed := (step + 1) * STEP
		arrival_warning_seen = arrival_warning_seen or (red.arrival_warning_started and red.overtake_warning_remaining > 0.0)
		if yielded_at < 0.0 and leader.lane != 0 and absf(leader.lane_position) >= 0.999:
			yielded_at = elapsed
		if passed_leader_at < 0.0 and red.y + red.half_length < leader.y - leader.half_length:
			passed_leader_at = elapsed
		if passed_player_at < 0.0 and red.y + red.half_length < Geometry.player_y(720.0):
			passed_player_at = elapsed
		if not traffic.vehicles.has(red):
			break
	print("FAST_PRIORITY_YIELD_WITNESS ", JSON.stringify({"yielded_at":yielded_at,"passed_leader_at":passed_leader_at,"passed_player_at":passed_player_at,"leader_lane":leader.lane,"leader_position":leader.lane_position,"red_y":red.y,"red_speed":red.actual_world_speed,"arrival_warning":arrival_warning_seen,"physical":traffic.physical_failures}))
	# 0.66s warning + 0.417s one-lane motion fits comfortably in 2 seconds.
	_check(yielded_at > 0.0 and yielded_at <= 2.0, "visible normal leader actively clears the red-car lane within 2s when the adjacent lane is empty")
	# Includes a full visible arrival warning, finite acceleration and 450px
	# of initial leader separation. No perpetual player escort is acceptable.
	_check(passed_leader_at > 0.0 and passed_leader_at <= 4.0, "red car safely passes the occupied lane within 4s in the yielding fixture")
	_check(passed_player_at > 0.0 and arrival_warning_seen, "red arrival has visible warning and then actually passes the player")
	_check(traffic.physical_failures.is_empty(), "yield/pass retains finite motion, visible turn warning, no body overlap and wall120")

func _test_unstarted_normal_merge_does_not_claim_fast_corridor() -> void:
	var traffic := _fixture()
	var merging = traffic.acquire_vehicle(Traffic.Kind.SIGNAL_CHANGE, 1, 180.0, 200.0)
	merging.target_lane = 0
	traffic.vehicles.append(merging)
	var red = _red(traffic, 0)
	var intrusion := false
	for step in 60:
		traffic.tick(STEP, PLAYER_SPEED, 2)
		intrusion = intrusion or (merging.target_lane == 0 and (merging.warning_started or merging.change_started))
	print("FAST_PRIORITY_MERGE_WITNESS ", JSON.stringify({"intrusion":intrusion,"target":merging.target_lane,"warning":merging.warning_started,"red_y":red.y}))
	_check(not intrusion, "ordinary unstarted lane-change intent cannot reserve or insert into an active red-car corridor")
	_check(traffic.physical_failures.is_empty(), "corridor reservation retains physical safety")

func _test_new_births_pause_and_resume_after_natural_pass() -> void:
	var traffic := _fixture(42)
	var red = _red(traffic)
	traffic._spawn_cooldown = 0.0
	var first_history := traffic.spawn_sequence()
	for step in 30:
		traffic.tick(STEP, PLAYER_SPEED, 2)
	var paused := traffic.spawn_sequence() == first_history
	var warning_seen: bool = red.arrival_warning_started and red.overtake_warning_remaining > 0.0
	var passed := false
	var retired := false
	for step in 600:
		traffic.tick(STEP, PLAYER_SPEED, 2)
		if traffic.vehicles.has(red):
			passed = passed or red.y + red.half_length < Geometry.player_y(720.0)
		else:
			retired = true
			break
	var resume_history := traffic.spawn_sequence()
	var recovery_player_speed := PLAYER_SPEED
	for step in 180:
		# Move past any already-born 200-speed cars with bounded acceleration,
		# otherwise a same-speed car can legitimately occupy the birth gate.
		recovery_player_speed = minf(360.0, recovery_player_speed + Config.ACCELERATION * STEP)
		traffic.tick(STEP, recovery_player_speed, 2)
	var resumed := traffic.spawn_sequence() != resume_history
	print("FAST_PRIORITY_BIRTH_WITNESS ", JSON.stringify({"paused":paused,"passed":passed,"retired":retired,"resumed":resumed,"warning":warning_seen,"history":traffic.spawn_sequence()}))
	_check(paused, "new ordinary traffic births pause while the visible red priority event is active")
	_check(passed and retired and resumed, "natural red pass and offscreen retirement release priority and ordinary births resume within 3s")
	_check(traffic.physical_failures.is_empty(), "priority birth lifecycle keeps continuous and body-safe motion")

func _test_new_construction_pauses() -> void:
	var traffic := _fixture(42)
	traffic.lane_events.enabled = true
	traffic.set_difficulty_stage(1)
	traffic.lane_events._cooldown_remaining = 0.0
	_red(traffic, 0)
	for step in 30:
		traffic.tick(STEP, PLAYER_SPEED, 2)
	print("FAST_PRIORITY_NEW_CONSTRUCTION_WITNESS ", JSON.stringify({"state":traffic.lane_events.state,"started":traffic.lane_events.events_started_count,"history":traffic.lane_events.event_history()}))
	_check(traffic.lane_events.state == Events.State.IDLE and traffic.lane_events.events_started_count == 0, "new construction is deferred during the active red priority event")

func _test_published_construction_is_not_erased_or_frozen() -> void:
	var traffic := _fixture(81)
	traffic.set_difficulty_stage(1)
	traffic.lane_events.enabled = true
	traffic.lane_events.begin_warning(0)
	# Publish by ordinary road-distance ticks before the red car arrives.
	for step in 150:
		traffic.lane_events.tick(STEP, 1, 2, PLAYER_SPEED)
	var before := traffic.lane_events.core_markers(720.0)
	var before_distance: float = traffic.lane_events._travel_distance
	var lanes_before := traffic.lane_events.closed_lanes()
	_check(not before.is_empty() and not traffic.lane_events.cone_markers(720.0).is_empty(), "construction fixture is visibly published by natural road motion")
	_red(traffic, 2)
	for step in 6:
		traffic.tick(STEP, PLAYER_SPEED, 1)
	var after := traffic.lane_events.core_markers(720.0)
	var expected_travel := PLAYER_SPEED * Config.ROAD_SCROLL_MULTIPLIER * STEP * 6.0
	print("FAST_PRIORITY_PUBLISHED_CONSTRUCTION_WITNESS ", JSON.stringify({"before":before,"after":after,"travel":traffic.lane_events._travel_distance - before_distance,"expected":expected_travel,"history":traffic.lane_events.event_history()}))
	_check(traffic.lane_events.closed_lanes() == lanes_before and not after.is_empty() and not traffic.lane_events.event_history().contains("cancelled:"), "red priority does not erase already-visible construction")
	_check(is_equal_approx(traffic.lane_events._travel_distance - before_distance, expected_travel), "published construction keeps moving with real road scroll during red priority")
	_check(traffic.physical_failures.is_empty(), "published construction fixture preserves finite traffic motion")

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
