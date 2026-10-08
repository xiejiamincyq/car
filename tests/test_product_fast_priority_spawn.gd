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
	var substep_count := 0
	func _tick_step(delta: float, player_speed: float, player_lane: int, frame_start: Dictionary) -> void:
		var before := _snapshot()
		for actor in vehicles:
			var key := _key(actor)
			if _is_lane_change_visible(actor):
				if actor.warning_started and not actor.change_started:
					turn_warning_seconds[key] = float(turn_warning_seconds.get(key, 0.0)) + delta
				if actor.arrival_warning_started and actor.overtake_warning_remaining > 0.0:
					arrival_warning_seconds[key] = float(arrival_warning_seconds.get(key, 0.0)) + delta
		super._tick_step(delta, player_speed, player_lane, frame_start)
		var after := _snapshot()
		for key in after:
			if not before.has(key):
				continue
			var old: Dictionary = before[key]
			var current: Dictionary = after[key]
			var rate: float = 420.0 if current.speed < old.speed else 140.0
			if absf(current.speed - old.speed) > rate * delta + 0.00001:
				_record("140/420 finite acceleration/braking")
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
	_test_natural_first_truck_uses_safe_other_lane()
	_test_active_priority_ordinary_birth_retries_safe_lane()
	_test_clearance_phase_still_pauses_births()
	_test_no_safe_lane_still_rejects_birth()
	for failure in failures:
		push_error("FAST_PRIORITY_SPAWN " + failure)
	print("FAST_PRIORITY_SPAWN failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_fast_priority_spawn.gd")
	quit(0 if failures.is_empty() else 1)

func _test_natural_first_truck_uses_safe_other_lane() -> void:
	var traffic := ObservedTraffic.new(317)
	traffic.set_difficulty_stage(3)
	var saw_truck := false
	for step in 90:
		traffic.tick(STEP, 560.0, 1)
		_check(traffic.all_active_spawns_are_fair(), "natural first truck schedule retains existing spawn fairness")
		for actor in traffic.vehicles:
			saw_truck = saw_truck or actor.kind == Traffic.Kind.TRUCK
	# The original 1.183s TRUCK draw is lane1 behind a lane0 car at -431:
	# it is rejected, but lane2 with the same drawn 144 cruise is fully legal.
	print("FAST_PRIORITY_SPAWN_TRUCK_WITNESS ", JSON.stringify({"saw_truck":saw_truck,"history":traffic.spawn_sequence(),"safety":traffic.safety_failures}))
	_check(saw_truck, "natural seed317 stage3 first truck schedule searches another legal entrance instead of discarding its only drawn lane")
	_check(traffic.safety_failures.is_empty(), "natural truck retry retains finite motion, bodies, wall120 and visible warnings")

func _priority_tail_fixture() -> ObservedTraffic:
	var traffic := ObservedTraffic.new(0)
	traffic.lane_events.enabled = false
	traffic._spawn_cooldown = 1000.0
	traffic._player_speed = 760.0
	traffic._player_lane = 1
	traffic.set_difficulty_stage(2)
	var existing = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 2, -402.65, 220.0)
	var red = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 1, 250.143829754673, 920.0)
	# Specified legal event-tail state: red has already visibly warned and passed
	# the player. The random ordinary draw uses real seed0 RNG, which picks lane2.
	red.arrival_warning_started = true
	red.overtake_warning_remaining = 0.0
	red.has_entered_viewport = true
	traffic.vehicles.assign([existing, red])
	traffic.fast_priority.refresh(traffic.vehicles)
	return traffic

func _test_active_priority_ordinary_birth_retries_safe_lane() -> void:
	var traffic := _priority_tail_fixture()
	var blocked = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 2, -620.0, 220.0)
	var legal = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, -620.0, 220.0)
	_check(traffic.fast_priority.active() and not traffic.fast_priority.needs_clearance_window(traffic), "ordinary retry fixture is active priority after its clearance phase")
	_check(not traffic._can_spawn_candidate(blocked, 760.0, 1), "drawn lane2 genuinely fails original gap admission")
	_check(traffic._can_spawn_candidate(legal, 760.0, 1), "lane0 with identical 220 assigned cruise passes every original admission gate")
	var initial_count := traffic.vehicles.size()
	traffic._spawn_next(760.0, 1)
	var born = traffic.vehicles.back() if traffic.vehicles.size() > initial_count else null
	print("FAST_PRIORITY_SPAWN_ORDINARY_WITNESS ", JSON.stringify({"initial_count":initial_count,"after_count":traffic.vehicles.size(),"history":traffic.spawn_sequence(),"born_lane":born.lane if born != null else -1,"born_cruise":born.cruise_speed if born != null else -1.0}))
	_check(born != null and born.kind == Traffic.Kind.STEADY_SLOW and born.lane == 0 and born.spawn_was_fair and is_equal_approx(born.cruise_speed, 220.0), "post-clearance active priority ordinary birth retries its safe unreserved lane without rerolling assigned cruise")
	for step in 120:
		traffic.tick(STEP, 760.0, 1)
	_check(traffic.safety_failures.is_empty(), "ordinary priority retry retains real finite motion, bodies, wall120, escape and warnings")

func _test_clearance_phase_still_pauses_births() -> void:
	var traffic := ObservedTraffic.new(0)
	traffic.lane_events.enabled = false
	traffic.set_difficulty_stage(2)
	traffic._spawn_cooldown = 0.0
	var red = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 650.0, 920.0)
	red.actual_world_speed = 200.0
	traffic.vehicles.append(red)
	for step in 15:
		traffic.tick(STEP, 200.0, 2)
	_check(traffic.spawn_sequence().is_empty() and traffic.vehicles.size() == 1, "safe lane fallback cannot bypass red arrival clearance pause")
	_check(traffic.safety_failures.is_empty(), "arrival pause keeps all real physical and warning constraints")

func _test_no_safe_lane_still_rejects_birth() -> void:
	var traffic := _priority_tail_fixture()
	traffic.vehicles.append(traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, -620.0, 220.0))
	var before := traffic.vehicles.size()
	_check(not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall(), "all-blocked birth fixture has valid existing physical state")
	traffic._spawn_next(760.0, 1)
	_check(traffic.vehicles.size() == before and traffic.spawn_sequence().is_empty(), "fallback cannot admit a birth when both unreserved entrances fail body gap")
	_check(not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall(), "rejected birth preserves body and wall safety")

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
