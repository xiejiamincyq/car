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
	_run_dense_case(false)
	_run_dense_case(true)
	for failure in failures:
		push_error("FAST_PRIORITY_DENSE " + failure)
	print("FAST_PRIORITY_DENSE failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_fast_priority_dense.gd")
	quit(0 if failures.is_empty() else 1)

func _run_dense_case(transient_front_braking: bool) -> void:
	var label := "transient_front_braking" if transient_front_braking else "dense_equal_speed_queue"
	var traffic := ObservedTraffic.new(611)
	traffic.set_viewport_height(720.0)
	traffic._spawn_cooldown = 1000.0
	traffic.lane_events.enabled = false
	# This is a specified, physically valid in-progress road state. It is not
	# claimed to be a reconstruction of randomized natural births.
	var partner = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 0, 250.0, 200.0)
	var yielding = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, 520.0 if transient_front_braking else 400.0, 200.0)
	var front = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, -20.0 if transient_front_braking else 0.0, 200.0)
	var red = traffic.acquire_vehicle(Traffic.Kind.FAST_OVERTAKE, 0, 650.0, 920.0)
	red.actual_world_speed = 200.0
	traffic.vehicles.assign([partner, yielding, front, red])
	_check(traffic.vehicles_keep_safe_gap_until_recycle(partner, red, 200.0), "%s starts with a brakeable red-to-own-leader gap" % label)
	_check(traffic.vehicles_keep_safe_gap_until_recycle(front, yielding, 200.0), "%s starts with a brakeable adjacent-lane queue gap" % label)
	_check(not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall(), "%s starts without physical overlap or wall120" % label)
	_check(not traffic.reachable_player_lanes(2, Geometry.player_y(720.0), Config.COLLISION_LONGITUDINAL_DISTANCE).is_empty(), "%s initially preserves immediate player escape" % label)
	if transient_front_braking:
		# A normal temporary impact target; the first and all later speed changes
		# must still obey 420 braking/140 acceleration, never a direct speed edit.
		front.impact_speed_offset = -100.0
	var original_npcs: Array = [partner, yielding, front]
	var original_generations: Array[int] = [partner.motion_generation, yielding.motion_generation, front.motion_generation]
	var red_generation: int = red.motion_generation
	var passed_all_at := -1.0
	var retired_at := -1.0
	var retired_forward := false
	var released := false
	var npc_retired_before_pass := false
	var cruises_unchanged := true
	var history: Array[Dictionary] = []
	for step in 720:
		traffic.tick(STEP, 200.0, 2)
		var elapsed := (step + 1) * STEP
		var red_live: bool = traffic.vehicles.has(red) and red.motion_generation == red_generation
		var all_original_npcs_live := true
		var ahead_of_every_npc := red_live
		for index in original_npcs.size():
			var npc = original_npcs[index]
			var npc_live: bool = traffic.vehicles.has(npc) and npc.motion_generation == original_generations[index]
			all_original_npcs_live = all_original_npcs_live and npc_live
			ahead_of_every_npc = ahead_of_every_npc and npc_live and red.y + red.half_length < npc.y - npc.half_length
			if npc_live:
				cruises_unchanged = cruises_unchanged and is_equal_approx(npc.cruise_speed, 200.0)
		if red_live:
			cruises_unchanged = cruises_unchanged and is_equal_approx(red.cruise_speed, 920.0)
		if passed_all_at < 0.0 and ahead_of_every_npc:
			passed_all_at = elapsed
		if passed_all_at < 0.0 and not all_original_npcs_live:
			npc_retired_before_pass = true
		if step % 60 == 0 or not red_live:
			history.append({"seconds":elapsed,"red_y":red.y,"red_speed":red.actual_world_speed,"red_lane":red.lane,"partner_y":partner.y,"partner_speed":partner.actual_world_speed,"yield_y":yielding.y,"yield_speed":yielding.actual_world_speed,"front_y":front.y,"front_speed":front.actual_world_speed,"red_live":red_live,"priority":traffic.fast_priority.active()})
		if not red_live:
			retired_at = elapsed
			retired_forward = red.motion_generation == red_generation and red.y <= Geometry.FAST_RECYCLE_Y
			released = not traffic.fast_priority.active()
			break
	print("FAST_PRIORITY_DENSE_WITNESS ", JSON.stringify({"case":label,"passed_all_at":passed_all_at,"retired_at":retired_at,"retired_forward":retired_forward,"released":released,"npc_retired_before_pass":npc_retired_before_pass,"cruises_unchanged":cruises_unchanged,"safety":traffic.safety_failures,"history":history}))
	_check(passed_all_at > 0.0 and passed_all_at <= 10.0 and not npc_retired_before_pass, "%s red actually passes all three original NPC bodies within 10s, not by deleting or retiring a front NPC" % label)
	_check(retired_at > 0.0 and retired_at <= 12.0 and retired_forward and released, "%s red naturally exits ahead and releases priority within 12s, never by slowing its own leader until red exits behind" % label)
	_check(cruises_unchanged, "%s preserves original assigned cruise speeds while coordinating real motion" % label)
	_check(traffic.safety_failures.is_empty(), "%s preserves finite motion, swept body safety, wall120, escape and visible warnings" % label)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
