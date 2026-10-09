extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const Geometry = preload("res://scripts/track_geometry.gd")
const Events = preload("res://scripts/lane_event_director.gd")
const Safety = preload("res://scripts/traffic_safety_policy.gd")
const STEP := 1.0 / 60.0
# Independent specification in the existing speed coordinate, not a copy of
# the production FAST_OVERTAKE_SPEED constant that could mask a wrong value.
const EXPECTED_WORLD_SPEED := 400.0 / 0.42
const PRE_ENTRY_WARNING_SECONDS := 1.0
var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	for height in [720.0, 1080.0]:
		for initial_player_speed in [0.0, 200.0, 820.0, 859.0, 1200.0]:
			_sample(height, initial_player_speed)
	_test_existing_staggered_traffic(false)
	_test_existing_staggered_traffic(true)
	_test_reserved_lane_rejects_turn()
	_test_existing_construction_is_preserved()
	_test_reset_discards_notice()
	for failure in failures:
		push_error("FAST_CONSTANT_ENTRY " + failure)
	print("FAST_CONSTANT_ENTRY assertions=%d failures=%d" % [assertions, failures.size()])
	print("TEST_COMPLETE test_product_fast_constant_entry.gd")
	quit(0 if failures.is_empty() else 1)

func _sample(height: float, initial_player_speed: float) -> void:
	var traffic := Traffic.new(611)
	traffic.set_viewport_height(height)
	traffic.lane_events.enabled = false
	traffic.set_difficulty_stage(2)
	traffic.track_pattern = &"coast_flow"
	# Choose a real production schedule position, not a replacement spawn or
	# manually acquired car. The real admission policy and tick create the red.
	traffic._schedule_cursor = 2
	traffic._spawn_cooldown = 0.0
	var label := "height%.0f player%.0f" % [height, initial_player_speed]
	var warning_seconds := 0.0
	var warning_lane := -1
	var warning_without_red := true
	var birth_seconds := -1.0
	var red = null
	for frame in 300:
		var warning := _entry_warning(traffic)
		if bool(warning.get("active", false)):
			warning_seconds += STEP
			warning_lane = int(warning.get("lane", -1))
			for actor in traffic.vehicles:
				if actor.kind == Traffic.Kind.FAST_OVERTAKE:
					warning_without_red = false
		traffic.tick(STEP, initial_player_speed, 1)
		for actor in traffic.vehicles:
			if actor.kind == Traffic.Kind.FAST_OVERTAKE:
				red = actor
		if red != null:
			birth_seconds = (frame + 1) * STEP
			break
	_check(red != null, label + " admits a production red birth on an empty safe road")
	if red == null:
		return
	traffic._spawn_cooldown = 1000.0
	_check(red.spawn_was_fair, label + " real birth passed production admission")
	_check(warning_seconds >= PRE_ENTRY_WARNING_SECONDS - STEP - 0.00001 and warning_without_red,
		label + " warns the lane for one second before any red entity exists, not after visible arrival")
	_check(warning_lane >= 0 and warning_lane < traffic.lane_count and warning_lane == red.lane,
		label + " pre-entry warning identifies the actual birth lane")
	_check(is_equal_approx(red.cruise_speed, EXPECTED_WORLD_SPEED), label + " assigned cruise is exactly displayed 400 km/h")
	_check(is_equal_approx(red.actual_world_speed, EXPECTED_WORLD_SPEED), label + " first production tick already travels at 400 km/h")
	var generation: int = red.motion_generation
	var observed_frames := 0
	var visible_frames := 0
	var speed_constant := true
	var projection_correct := true
	var physically_safe := true
	var history: Array[Dictionary] = []
	for frame in 180:
		if not traffic.vehicles.has(red) or red.motion_generation != generation:
			break
		# The same real red must not inherit the player's changing camera speed:
		# sudden player braking, maximum normal cruise, and overdrive above 400.
		var player_speed := initial_player_speed
		if frame >= 30 and frame < 60:
			player_speed = 0.0
		elif frame >= 60 and frame < 90:
			player_speed = 859.0
		elif frame >= 90 and frame < 120:
			player_speed = 1200.0
		var old_y: float = red.y
		traffic.tick(STEP, player_speed, 1)
		observed_frames += 1
		if red.y + red.half_length >= 0.0 and red.y - red.half_length <= height:
			visible_frames += 1
		speed_constant = speed_constant and is_equal_approx(red.actual_world_speed, EXPECTED_WORLD_SPEED)
		var expected_y: float = old_y + (player_speed - EXPECTED_WORLD_SPEED) * 1.15 * STEP
		projection_correct = projection_correct and absf(red.y - expected_y) < 0.00001
		physically_safe = physically_safe and not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall()
		if frame % 15 == 0:
			history.append({"frame":frame,"player_speed":player_speed,"red_speed":red.actual_world_speed,"red_y":red.y,"expected_y":expected_y})
	_check(observed_frames > 0 and speed_constant, label + " keeps 400 km/h throughout real ticks even when player brakes or overdrives")
	_check(projection_correct, label + " relative camera displacement equals (player - absolute red) * 1.15 * dt without catch-up or teleport")
	_check(physically_safe, label + " empty-road run preserves NPC body and wall safety")
	# This oracle does not claim full traffic safety or player collision coverage:
	# no other NPC/obstacle was inserted, and the player is in a different lane.
	print("FAST_CONSTANT_ENTRY_WITNESS ", JSON.stringify({"case":label,"birth_seconds":birth_seconds,"warning_seconds":warning_seconds,"warning_lane":warning_lane,"birth_lane":red.lane,"frames":observed_frames,"visible_frames":visible_frames,"constant":speed_constant,"projection":projection_correct,"history":history}))

func _entry_warning(traffic) -> Dictionary:
	# Missing warning state is an assertion failure rather than a parser error.
	# The returned state is also used by the real warning renderer.
	if not traffic.has_method("fast_entry_warning"):
		return {}
	var state: Variant = traffic.call("fast_entry_warning")
	return state if state is Dictionary else {}

func _production_host():
	var traffic := Traffic.new(611)
	traffic.set_viewport_height(720.0)
	traffic.set_difficulty_stage(2)
	traffic.track_pattern = &"coast_flow"
	traffic._schedule_cursor = 2
	traffic._spawn_cooldown = 0.0
	traffic.lane_events.enabled = false
	return traffic

func _test_existing_staggered_traffic(preferred_lane_occupied: bool) -> void:
	var traffic = _production_host()
	var first_lane := 0 if preferred_lane_occupied else 2
	var front = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, 1, 120.0, 200.0)
	var rear = traffic.acquire_vehicle(Traffic.Kind.STEADY_SLOW, first_lane, 460.0, 200.0)
	var label := "staggered preferred_lane_occupied=%s" % preferred_lane_occupied
	_check(traffic._can_spawn_candidate(front, 200.0, 1), label + " front initial NPC is legally admitted")
	traffic.vehicles.append(front)
	_check(traffic._can_spawn_candidate(rear, 200.0, 1), label + " second initial NPC is legally admitted")
	traffic.vehicles.append(rear)
	_check(not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall(), label + " initial scene is legal")
	var generations: Array[int] = [front.motion_generation, rear.motion_generation]
	var notice_lane := -1
	var notice_seconds := 0.0
	var birth_at := -1.0
	var pass_at := -1.0
	var red = null
	var safe := true
	var retained := true
	var reservation_preserved := true
	var fixed_speed := true
	for frame in 360:
		var notice := _entry_warning(traffic)
		if bool(notice.get("active", false)):
			if notice_lane < 0: notice_lane = int(notice.lane)
			reservation_preserved = reservation_preserved and notice_lane == int(notice.lane)
			notice_seconds += STEP
		var before := _body_snapshot(traffic)
		traffic.tick(STEP, 200.0, 1)
		safe = safe and _continuous_bodies_safe(before, _body_snapshot(traffic)) and not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall()
		for index in 2:
			var actor = front if index == 0 else rear
			retained = retained and traffic.vehicles.has(actor) and actor.motion_generation == generations[index]
			if notice_lane >= 0 and (bool(_entry_warning(traffic).get("active", false)) or red != null):
				reservation_preserved = reservation_preserved and not Safety.reserved_lanes(actor).has(notice_lane)
		for actor in traffic.vehicles:
			if actor.kind == Traffic.Kind.FAST_OVERTAKE:
				if red == null:
					red = actor
					birth_at = (frame + 1) * STEP
					_check(actor.lane == notice_lane, label + " actual birth uses the announced lane")
		if red != null:
			fixed_speed = fixed_speed and is_equal_approx(red.actual_world_speed, EXPECTED_WORLD_SPEED)
			if red.y + red.half_length < minf(front.y - front.half_length, rear.y - rear.half_length) and pass_at < 0.0:
				pass_at = (frame + 1) * STEP
			if not traffic.vehicles.has(red): break
	_check(red != null and pass_at > 0.0, label + " at least one actual natural constant-speed red passes both existing NPCs")
	_check(notice_seconds >= 1.0 - STEP - 0.00001 and reservation_preserved, label + " one-second published lane stays reserved for the actual pass")
	_check(retained, label + " retains both originally visible NPC bodies and generations")
	_check(safe and fixed_speed, label + " finite projected movement preserves swept bodies, wall120 and fixed red speed")
	print("FAST_CONSTANT_TRAFFIC_WITNESS ", JSON.stringify({"case":label,"birth_at":birth_at,"pass_at":pass_at,"notice_lane":notice_lane,"warning_seconds":notice_seconds,"retained":retained,"safe":safe,"constant":fixed_speed,"reservation":reservation_preserved}))

func _test_reserved_lane_rejects_turn() -> void:
	var traffic = _production_host()
	# This real SIGNAL_CHANGE car plans to merge into the preferred red lane0;
	# production priority must cancel/defer it before publishing the pass lane.
	var turning = traffic.acquire_vehicle(Traffic.Kind.SIGNAL_CHANGE, 1, 160.0, 200.0)
	_check(turning.target_lane == 0 and traffic._can_spawn_candidate(turning, 200.0, 1), "incoming turn fixture is a legal natural lane0 intent")
	traffic.vehicles.append(turning)
	var announced := false
	var reserved_lane := -1
	var intrusion := false
	var red = null
	for frame in 240:
		traffic.tick(STEP, 200.0, 1)
		var notice := _entry_warning(traffic)
		if bool(notice.get("active", false)):
			announced = true
			reserved_lane = int(notice.lane)
		for actor in traffic.vehicles:
			if actor.kind == Traffic.Kind.FAST_OVERTAKE: red = actor
		if announced and (bool(notice.get("active", false)) or red != null):
			intrusion = intrusion or Safety.reserved_lanes(turning).has(reserved_lane)
		if red != null and not traffic.vehicles.has(red): break
	_check(announced and red != null, "real incoming turn fixture reaches a published warning and red birth")
	_check(not intrusion and traffic.vehicles.has(turning), "ordinary turn never intrudes into the published pass lane and is not erased")
	print("FAST_CONSTANT_RESERVED_TURN ", JSON.stringify({"announced":announced,"birth":red != null,"lane":reserved_lane,"intrusion":intrusion,"npc_lane":turning.lane,"npc_target":turning.target_lane}))

func _test_existing_construction_is_preserved() -> void:
	var traffic = _production_host()
	traffic.lane_events.enabled = true
	traffic.lane_events.event_limit = 1
	traffic.lane_events.begin_warning(2)
	# Real event travel makes the previously announced leading cones visible;
	# no synthetic obstacle deletion/flag or forced red admission is used.
	traffic.lane_events.tick(1.0, 2, 1, 200.0)
	_check(not traffic.lane_events.cone_markers(720.0).is_empty(), "construction fixture begins with visible original cones")
	var event_ended_at := -1.0
	var first_warning_at := -1.0
	var red_birth_at := -1.0
	var retained := true
	var red_during_event := false
	var warning_during_event := false
	for frame in 720:
		var old_cones: Array[Dictionary] = traffic.lane_events.cone_markers(720.0)
		var before_state: int = traffic.lane_events.state
		traffic.tick(STEP, 200.0, 1)
		var elapsed := (frame + 1) * STEP
		var event_active: bool = traffic.lane_events.state != Events.State.IDLE
		if before_state != Events.State.IDLE and not event_active and event_ended_at < 0.0: event_ended_at = elapsed
		var after_cones: Array[Dictionary] = traffic.lane_events.cone_markers(720.0)
		for old_cone in old_cones:
			var expected_y: float = float(old_cone.y) + 200.0 * 1.15 * STEP
			if expected_y > 780.0: continue
			var match_found := false
			for next_cone in after_cones:
				if int(next_cone.id) == int(old_cone.id) and absf(float(next_cone.y) - expected_y) < 0.00001:
					match_found = true
			retained = retained and match_found
		var notice := _entry_warning(traffic)
		if bool(notice.get("active", false)):
			if first_warning_at < 0.0: first_warning_at = elapsed
			warning_during_event = warning_during_event or event_active
		for actor in traffic.vehicles:
			if actor.kind == Traffic.Kind.FAST_OVERTAKE:
				if red_birth_at < 0.0: red_birth_at = elapsed
				red_during_event = red_during_event or event_active
		if event_ended_at > 0.0 and elapsed > event_ended_at + 2.0: break
	_check(retained and not traffic.lane_events.event_history().contains("cancelled"), "red preparation never removes/teleports previously visible construction cones")
	_check(event_ended_at > 0.0 and not red_during_event and not warning_during_event, "existing whole construction ends naturally before any constant-red warning or birth")
	_check(first_warning_at < 0.0 or first_warning_at >= event_ended_at, "safe gate may defer/abandon unannounced pass rather than deleting construction")
	print("FAST_CONSTANT_CONSTRUCTION_WITNESS ", JSON.stringify({"event_ended_at":event_ended_at,"warning_at":first_warning_at,"birth_at":red_birth_at,"retained":retained,"red_during_event":red_during_event,"warning_during_event":warning_during_event,"history":traffic.lane_events.event_history()}))

func _test_reset_discards_notice() -> void:
	var traffic = _production_host()
	traffic.tick(STEP, 200.0, 1)
	_check(bool(_entry_warning(traffic).get("active", false)) and traffic.vehicles.is_empty(), "reset fixture reaches actual pre-entry warning with no red entity")
	traffic.reset(9001)
	_check(not bool(_entry_warning(traffic).get("active", false)) and int(_entry_warning(traffic).get("lane", -1)) == -1 and not traffic.fast_priority.active(), "reset clears pending notice, reserved lane and priority owner")
	var stale_red := false
	var stale_notice := false
	for frame in 180:
		traffic.tick(STEP, 200.0, 1)
		stale_notice = stale_notice or bool(_entry_warning(traffic).get("active", false))
		for actor in traffic.vehicles:
			stale_red = stale_red or actor.kind == Traffic.Kind.FAST_OVERTAKE
	_check(not stale_red and not stale_notice and not traffic.lane_events.scheduling_paused, "new stage0 run cannot inherit previous pending red, lane notice or paused construction")

func _body_snapshot(traffic) -> Dictionary:
	var result: Dictionary = {}
	for actor in traffic.vehicles:
		result["%d:%d" % [actor.get_instance_id(), actor.motion_generation]] = {"x":actor.lane_position * (Config.ROAD_HALF_WIDTH * 2.0 / 3.0),"y":actor.y,"width":actor.half_width,"length":actor.half_length}
	return result

func _continuous_bodies_safe(before: Dictionary, after: Dictionary) -> bool:
	var keys := before.keys()
	for first_index in keys.size():
		for second_index in range(first_index + 1, keys.size()):
			var first: String = keys[first_index]
			var second: String = keys[second_index]
			if not after.has(first) or not after.has(second): continue
			var a0: Dictionary = before[first]
			var b0: Dictionary = before[second]
			var a1: Dictionary = after[first]
			var b1: Dictionary = after[second]
			var x := _inside_interval(a0.x - b0.x, a1.x - b1.x, a0.width + b0.width + 4.0)
			var y := _inside_interval(a0.y - b0.y, a1.y - b1.y, a0.length + b0.length + 4.0)
			if maxf(x.x, y.x) < minf(x.y, y.y) - 0.0000001: return false
	return true

func _inside_interval(start: float, finish: float, limit: float) -> Vector2:
	if is_equal_approx(start, finish):
		return Vector2(0.0, 1.0) if absf(start) < limit else Vector2(2.0, -1.0)
	var first := (-limit - start) / (finish - start)
	var second := (limit - start) / (finish - start)
	return Vector2(maxf(0.0, minf(first, second)), minf(1.0, maxf(first, second)))

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition and not failures.has(message):
		failures.append(message)
