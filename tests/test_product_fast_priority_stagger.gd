extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const STEP := 1.0 / 60.0
var failures: Array[String] = []

class ObservedTraffic extends Traffic:
	var safety_failures: Array[String] = []
	var turn_warning_seconds: Dictionary = {}
	var checked_turns: Dictionary = {}
	var arrival_warning_seconds: Dictionary = {}
	var entry_exposure := 0.0
	var entry_lane := -1
	var substep_count := 0
	func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
		var before := _snapshot()
		var notice := fast_entry_warning()
		if notice.active:
			entry_exposure = entry_exposure + delta if entry_lane == notice.lane else delta
			entry_lane = notice.lane
		else:
			entry_exposure = 0.0
			entry_lane = -1
		for actor in vehicles:
			var key := _key(actor)
			if _is_lane_change_visible(actor):
				if actor.warning_started and not actor.change_started:
					turn_warning_seconds[key] = float(turn_warning_seconds.get(key, 0.0)) + delta
				if actor.arrival_warning_started and actor.overtake_warning_remaining > 0.0:
					arrival_warning_seconds[key] = float(arrival_warning_seconds.get(key, 0.0)) + delta
		super._tick_step(delta, player_speed, player_lane, frame_start)
		var after := _snapshot()
		for actor in vehicles:
			if not before.has(_key(actor)) and actor.kind == Kind.FAST_OVERTAKE and actor.lane == entry_lane:
				arrival_warning_seconds[_key(actor)] = entry_exposure
		for key in after:
			if not before.has(key):
				continue
			var old: Dictionary = before[key]
			var current: Dictionary = after[key]
			var rate: float = 420.0 if current.speed < old.speed else (360.0 if current.kind == Kind.FAST_OVERTAKE else 140.0)
			if absf(current.speed - old.speed) > rate * delta + 0.00001:
				_record("kind-specific finite acceleration/braking")
			var expected_y: float = old.y + (player_speed - current.speed) * Config.ROAD_SCROLL_MULTIPLIER * delta
			if absf(current.y - expected_y) > 0.00001:
				_record("continuous longitudinal movement without teleport")
			var maximum_lateral_speed: float = FAST_LANE_CHANGE_SPEED if current.kind == Kind.FAST_OVERTAKE else NORMAL_LANE_CHANGE_SPEED
			if absf(current.position - old.position) > maximum_lateral_speed * delta + 0.00001:
				_record("continuous lateral movement")
			if absf(current.position - old.position) > 0.00001 and not checked_turns.has(key):
				checked_turns[key] = true
				var warning_required: float = FAST_ROUTE_WARNING_SECONDS if current.kind == Kind.FAST_OVERTAKE else lane_change_warning_duration()
				if float(turn_warning_seconds.get(key, 0.0)) < warning_required - STEP - 0.00001:
					_record("visible turn warning before first sideways movement")
			if current.kind == Kind.FAST_OVERTAKE and old.y + old.length >= Geometry.player_y(_viewport_height) and current.y + current.length < Geometry.player_y(_viewport_height):
				if float(arrival_warning_seconds.get(key, 0.0)) < 1.0 - STEP - 0.00001:
					_record("one full visible red arrival warning before passing player")
		var keys := before.keys()
		for first_index in keys.size():
			for second_index in range(first_index + 1, keys.size()):
				var first: String = keys[first_index]
				var second: String = keys[second_index]
				if not after.has(first) or not after.has(second):
					continue
				if _swept_overlap(before[first], before[second], after[first], after[second]):
					_record("no swept physical body overlap")
		if has_vehicle_overlap():
			_record("no endpoint physical body overlap")
		if has_full_lane_wall():
			_record("wall120 must remain intact")
		if reachable_player_lanes(player_lane, Geometry.player_y(_viewport_height), Config.COLLISION_LONGITUDINAL_DISTANCE).is_empty():
			_record("immediate player escape remains available")
		substep_count += 1
	func _key(actor) -> String:
		return "%d:%d" % [actor.get_instance_id(), actor.motion_generation]
	func _snapshot() -> Dictionary:
		var result: Dictionary = {}
		for actor in vehicles:
			result[_key(actor)] = {"kind":actor.kind,"y":actor.y,"position":actor.lane_position,"speed":actor.actual_world_speed,"length":actor.half_length,"width":actor.half_width}
		return result
	func _record(message: String) -> void:
		if not safety_failures.any(func(existing: String) -> bool: return existing.begins_with(message)):
			safety_failures.append(message + " at substep %d" % substep_count)
	func _swept_overlap(a0: Dictionary, b0: Dictionary, a1: Dictionary, b1: Dictionary) -> bool:
		var lane_width: float = Config.ROAD_HALF_WIDTH * 2.0 / lane_count
		var x_interval := _inside_interval((a0.position - b0.position) * lane_width, (a1.position - b1.position) * lane_width, a0.width + b0.width + 4.0)
		var y_interval := _inside_interval(a0.y - b0.y, a1.y - b1.y, a0.length + b0.length + 4.0)
		return maxf(x_interval.x, y_interval.x) < minf(x_interval.y, y_interval.y) - 0.0000001
	func _inside_interval(start: float, finish: float, limit: float) -> Vector2:
		if is_equal_approx(start, finish):
			return Vector2(0.0, 1.0) if absf(start) < limit else Vector2(2.0, -1.0)
		var first := (-limit - start) / (finish - start)
		var second := (limit - start) / (finish - start)
		return Vector2(maxf(0.0, minf(first, second)), minf(1.0, maxf(first, second)))

func _init() -> void:
	_test_yield_respects_existing_lane_change_cooldown()
	_test_fair_stage_two_center_birth()
	for initial_y in [150.0, 250.0, 350.0]:
		_test_same_lane_leader_with_parallel_neighbor(initial_y)
	for failure in failures:
		push_error("FAST_PRIORITY_STAGGER " + failure)
	print("FAST_PRIORITY_STAGGER failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_fast_priority_stagger.gd")
	quit(0 if failures.is_empty() else 1)

func _fixture() -> ObservedTraffic:
	var traffic := ObservedTraffic.new(611)
	traffic.set_viewport_height(720.0)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	return traffic

func _test_yield_respects_existing_lane_change_cooldown() -> void:
	var traffic := _fixture()
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 200.0, 200.0)
	leader.lane_change_cooldown = 0.75
	var red = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 650.0, 920.0)
	red.actual_world_speed = 200.0
	traffic.vehicles.assign([leader, red])
	traffic.tick(STEP, 200.0, 2)
	print("FAST_PRIORITY_STAGGER_COOLDOWN_WITNESS ", JSON.stringify({"remaining":leader.lane_change_cooldown,"warning":leader.warning_started,"moving":leader.change_started,"target":leader.target_lane}))
	_check(leader.lane_change_cooldown > 0.0 and not leader.warning_started and not leader.change_started, "priority yielding honors the existing 0.75s cooldown and cannot restart warning after one tick")
	_check(traffic.safety_failures.is_empty(), "yield cooldown fixture preserves all motion and safety constraints")

func _test_fair_stage_two_center_birth() -> void:
	var traffic := _fixture()
	var left = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, -620.0, 200.0)
	_check(traffic._can_spawn_candidate(left, 360.0, 1), "left pair member has legal ordinary admission")
	traffic.vehicles.append(left)
	var right = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 2, -620.0, 200.0)
	_check(traffic._can_spawn_candidate(right, 360.0, 1), "opposite pair member has legal ordinary admission")
	traffic.vehicles.append(right)
	for step in 240:
		traffic.tick(STEP, 360.0, 1)
	var player_speed := 360.0
	while player_speed > 200.0:
		player_speed = maxf(200.0, player_speed - Config.BRAKING * STEP)
		traffic.tick(STEP, player_speed, 1)
	traffic.set_difficulty_stage(2)
	traffic._schedule_cursor = 2
	traffic._spawn_next(200.0, 1)
	var red = null
	for step in 300:
		traffic.tick(STEP,200.0,1)
		for actor in traffic.vehicles:
			if actor.kind == Traffic.Kind.FAST_OVERTAKE: red = actor
		if red != null: break
	_check(red != null, "production stage2 scheduler births a red car against the legal parallel pair")
	if red == null:
		return
	_check(red.spawn_was_fair and red.lane == 1, "production fairness selects the center red entrance")
	traffic._spawn_cooldown = 0.0
	_run_pass_case(traffic, red, left, right, 1, "fair_stage2_center_birth")

func _test_same_lane_leader_with_parallel_neighbor(initial_y: float) -> void:
	var traffic := _fixture()
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, initial_y, 200.0)
	var neighbor = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, initial_y, 200.0)
	var red = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 650.0, 920.0)
	red.actual_world_speed = 200.0
	traffic.vehicles.assign([leader, neighbor, red])
	_check(traffic.vehicles_keep_safe_gap_until_recycle(leader, red, 200.0), "parallel leader y%.0f has an initially brakeable red gap" % initial_y)
	_run_pass_case(traffic, red, leader, neighbor, 2, "own_lane_leader_y%.0f" % initial_y)

func _run_pass_case(traffic: ObservedTraffic, red, first, second, player_lane: int, label: String) -> void:
	var red_generation: int = red.motion_generation
	var first_generation: int = first.motion_generation
	var second_generation: int = second.motion_generation
	var passed_both_at := -1.0
	var retired_at := -1.0
	var released := false
	var retired_forward := false
	var first_departed_before_pass := false
	var witness: Array[Dictionary] = []
	for step in 600:
		traffic.tick(STEP, 200.0, player_lane)
		var elapsed := (step + 1) * STEP
		var red_live: bool = traffic.vehicles.has(red) and red.motion_generation == red_generation
		var first_live: bool = traffic.vehicles.has(first) and first.motion_generation == first_generation
		var second_live: bool = traffic.vehicles.has(second) and second.motion_generation == second_generation
		if red_live and first_live and second_live and passed_both_at < 0.0 and red.y + red.half_length < minf(first.y - first.half_length, second.y - second.half_length):
			passed_both_at = elapsed
		if passed_both_at < 0.0 and (not first_live or not second_live):
			first_departed_before_pass = true
		if step % 60 == 0 or not red_live:
			witness.append({"seconds":elapsed,"red_y":red.y,"red_speed":red.actual_world_speed,"first_y":first.y,"second_y":second.y,"red_live":red_live,"priority":traffic.fast_priority.active()})
		if not red_live:
			retired_at = elapsed
			retired_forward = red.motion_generation == red_generation and red.y <= Geometry.FAST_RECYCLE_Y
			released = not traffic.fast_priority.active()
			break
	print("FAST_PRIORITY_STAGGER_WITNESS ", JSON.stringify({"case":label,"passed_both_at":passed_both_at,"retired_at":retired_at,"retired_forward":retired_forward,"released":released,"leader_departed_before_pass":first_departed_before_pass,"safety":traffic.safety_failures,"history":witness}))
	_check(passed_both_at > 0.0 and passed_both_at <= 8.0 and not first_departed_before_pass, "%s red safely passes both original parallel NPC bodies within 8s, not by retiring its front vehicle" % label)
	_check(retired_at > 0.0 and retired_at <= 10.0 and retired_forward and released, "%s red naturally exits ahead and releases priority within 10s, not by falling behind" % label)
	_check(traffic.safety_failures.is_empty(), "%s keeps finite acceleration, swept bodies, wall120, player escape and visible warnings" % label)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
