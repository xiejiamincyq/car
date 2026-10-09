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
	for red_y in [650.0, 675.0]:
		_test_rear_own_leader(red_y)
	_test_four_car_fair_admission_after_transient_impact()
	for failure in failures:
		push_error("FAST_PRIORITY_REAR_LEADER " + failure)
	print("FAST_PRIORITY_REAR_LEADER failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_fast_priority_rear_leader.gd")
	quit(0 if failures.is_empty() else 1)

func _fixture() -> ObservedTraffic:
	var traffic := ObservedTraffic.new(611)
	traffic.set_viewport_height(720.0)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	return traffic

func _test_rear_own_leader(initial_red_y: float) -> void:
	var traffic := _fixture()
	var leader = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 350.0, 200.0)
	var neighbor = traffic.acquire_vehicle(Traffic.Kind.TRUCK, 1, 80.0, 160.0)
	var red = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, initial_red_y, 920.0)
	red.actual_world_speed = 200.0
	traffic.vehicles.assign([leader, neighbor, red])
	var label := "rear_own_leader_red_y%.0f" % initial_red_y
	# A valid specified mid-road state, not claimed to be random natural birth.
	_check(traffic.vehicles_keep_safe_gap_until_recycle(leader, red, 200.0), "%s starts with a brakeable own-leader gap" % label)
	_check(not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall(), "%s starts without physical overlap or wall120" % label)
	_check(not traffic.reachable_player_lanes(2, Geometry.player_y(720.0), Config.COLLISION_LONGITUDINAL_DISTANCE).is_empty(), "%s initially has player escape" % label)
	_run_pass(traffic, red, [leader, neighbor], [200.0, 160.0], 2, label)

func _test_four_car_fair_admission_after_transient_impact() -> void:
	var traffic := _fixture()
	var partner = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 250.0, 200.0)
	var opposite = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 2, 250.0, 200.0)
	var rear = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, 520.0, 200.0)
	var front = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, -20.0, 200.0)
	var original_npcs: Array = [partner, opposite, rear, front]
	for actor in original_npcs:
		_check(traffic._can_spawn_candidate(actor, 180.0, 1), "four-car fixture admits ordinary lane%d y%.0f through real fairness policy" % [actor.lane, actor.y])
		traffic.vehicles.append(actor)
	# Reproduce a legal transient speed target, not the complete player collision
	# chain: all subsequent motion is real tick with finite acceleration/braking.
	front.impact_speed_offset = -100.0
	for step in 180:
		traffic.tick(STEP, 200.0, 1)
	traffic.set_difficulty_stage(2)
	traffic._schedule_cursor = 2
	traffic._spawn_next(200.0, 1)
	var red = null
	for step in 300:
		traffic.tick(STEP,200.0,1)
		for actor in traffic.vehicles:
			if actor.kind == Traffic.Kind.FAST_OVERTAKE: red = actor
		if red != null: break
	_check(red != null, "four-car fixture receives a production stage2 red birth after real transient-impact motion")
	if red == null:
		return
	_check(red.spawn_was_fair, "four-car red birth passes production fairness")
	print("FAST_PRIORITY_REAR_LEADER_FAIR_BIRTH ", JSON.stringify({"red_lane":red.lane,"red_y":red.y,"red_actual":red.actual_world_speed,"partner_y":partner.y,"opposite_y":opposite.y,"rear_y":rear.y,"front_y":front.y}))
	_run_pass(traffic, red, original_npcs, [200.0, 200.0, 200.0, 200.0], 1, "fair_four_car_transient_impact")

func _run_pass(traffic: ObservedTraffic, red, original_npcs: Array, assigned_speeds: Array, player_lane: int, label: String) -> void:
	var original_generations: Array[int] = []
	for npc in original_npcs:
		original_generations.append(npc.motion_generation)
	var red_generation: int = red.motion_generation
	var assigned_red_speed: float = red.cruise_speed
	var passed_all_at := -1.0
	var retired_at := -1.0
	var retired_forward := false
	var released := false
	var npc_retired_before_pass := false
	var cruises_unchanged := true
	var history: Array[Dictionary] = []
	for step in 720:
		traffic.tick(STEP, 200.0, player_lane)
		var elapsed := (step + 1) * STEP
		var red_live: bool = traffic.vehicles.has(red) and red.motion_generation == red_generation
		var all_original_npcs_live := true
		var ahead_of_every_npc := red_live
		var npc_states: Array[Dictionary] = []
		for index in original_npcs.size():
			var npc = original_npcs[index]
			var npc_live: bool = traffic.vehicles.has(npc) and npc.motion_generation == original_generations[index]
			all_original_npcs_live = all_original_npcs_live and npc_live
			ahead_of_every_npc = ahead_of_every_npc and npc_live and red.y + red.half_length < npc.y - npc.half_length
			if npc_live:
				cruises_unchanged = cruises_unchanged and is_equal_approx(npc.cruise_speed, float(assigned_speeds[index]))
			npc_states.append({"lane":npc.lane,"target":npc.target_lane,"y":npc.y,"speed":npc.actual_world_speed,"warning":npc.warning_started,"moving":npc.change_started,"live":npc_live})
		if red_live:
			cruises_unchanged = cruises_unchanged and is_equal_approx(red.cruise_speed, assigned_red_speed)
		if passed_all_at < 0.0 and ahead_of_every_npc:
			passed_all_at = elapsed
		if passed_all_at < 0.0 and not all_original_npcs_live:
			npc_retired_before_pass = true
		if step % 60 == 0 or not red_live:
			history.append({"seconds":elapsed,"red_y":red.y,"red_speed":red.actual_world_speed,"red_lane":red.lane,"red_target":red.target_lane,"red_warning":red.warning_started,"red_live":red_live,"priority":traffic.fast_priority.active(),"npcs":npc_states})
		if not red_live:
			retired_at = elapsed
			retired_forward = red.motion_generation == red_generation and red.y <= Geometry.FAST_RECYCLE_Y
			released = not traffic.fast_priority.active()
			break
	print("FAST_PRIORITY_REAR_LEADER_WITNESS ", JSON.stringify({"case":label,"passed_all_at":passed_all_at,"retired_at":retired_at,"retired_forward":retired_forward,"released":released,"npc_retired_before_pass":npc_retired_before_pass,"cruises_unchanged":cruises_unchanged,"safety":traffic.safety_failures,"history":history}))
	_check(passed_all_at > 0.0 and passed_all_at <= 10.0 and not npc_retired_before_pass, "%s red actually passes every original NPC body within 10s, not by retiring its own leader" % label)
	_check(retired_at > 0.0 and retired_at <= 12.0 and retired_forward and released, "%s red naturally exits ahead and releases priority within 12s, not by falling behind after its own leader brakes" % label)
	_check(cruises_unchanged, "%s leaves assigned cruise speeds unchanged" % label)
	_check(traffic.safety_failures.is_empty(), "%s preserves finite motion, swept bodies, wall120, player escape and visible warnings" % label)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
