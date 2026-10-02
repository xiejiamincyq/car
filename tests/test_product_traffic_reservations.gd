extends SceneTree
## Small pure-model gate: real substeps, independent rectangles, no player saves.
const Traffic = preload("res://scripts/traffic_director.gd")
const Config = preload("res://scripts/game_config.gd")
const STEPS := [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.1, 0.25]
const LANE_WIDTH := Config.ROAD_HALF_WIDTH * 2.0 / 3.0
const STEADY := Traffic.Kind.STEADY_SLOW
const SIGNAL := Traffic.Kind.SIGNAL_CHANGE
const TRUCK := Traffic.Kind.TRUCK
var failures := 0

class ObservedTraffic extends Traffic:
	var contact := ""
	var observed_substeps := 0
	var warned: Dictionary = {}
	var started: Dictionary = {}
	var completed: Dictionary = {}
	var minimum_speed := INF
	var core_visible := false
	func _tick_step(delta: float, speed: float, player_lane: int, frame_start: Dictionary) -> void:
		var before := _bodies()
		var cores_before := _cores()
		super._tick_step(delta, speed, player_lane, frame_start)
		observed_substeps += 1
		var after := _bodies()
		var cores_after := _cores()
		for identity in before:
			var body: Dictionary = before[identity]
			if not after.has(identity):
				var final_y: float = body.vehicle.y
				if final_y + body.half.y >= 0.0 and final_y - body.half.y <= 720.0:
					_note("visible NPC deleted")
		for identity in after:
			var body: Dictionary = after[identity]
			var start: Vector2 = before[identity].position if before.has(identity) else body.position
			var vehicle = body.vehicle
			if before.has(identity):
				if absf(vehicle.actual_world_speed - before[identity].speed) > 420.0 * delta + 0.00001:
					_note("non-finite longitudinal braking/acceleration")
				# GDScript float is double; Vector2 snapshots round to single precision.
				var lateral_distance: float = absf(vehicle.lane_position - before[identity].lane_position) * LANE_WIDTH
				if lateral_distance > 2.4 * LANE_WIDTH * delta + 0.00001:
					_note("lateral displacement exceeded normal-car speed budget: dx=%.12f budget=%.12f" % [lateral_distance, 2.4 * LANE_WIDTH * delta])
			minimum_speed = minf(minimum_speed, vehicle.actual_world_speed)
			if vehicle.warning_started:
				warned[identity] = true
			if vehicle.change_started:
				started[identity] = true
			if before.has(identity) and before[identity].moving and not vehicle.change_started and vehicle.lane == vehicle.target_lane:
				completed[identity] = true
			for other_identity in after:
				if other_identity <= identity:
					continue
				var other: Dictionary = after[other_identity]
				var other_start: Vector2 = before[other_identity].position if before.has(other_identity) else other.position
				if swept_contact(start - other_start, body.position - other.position, body.half + other.half):
					_note("NPC swept body contact %s -> %s / %s -> %s" % [start, body.position, other_start, other.position])
			for lane in cores_after:
				var core: Vector2 = cores_after[lane]
				var core_start: Vector2 = cores_before.get(lane, core)
				core_visible = core_visible or (core.y >= 0.0 and core.y <= 720.0)
				if swept_contact(start - core_start, body.position - core, body.half + Vector2(LANE_WIDTH * Config.LANE_EVENT_CORE_HALF_LANE_RATIO, 20.0)):
					_note("NPC/core swept contact %s -> %s / %s -> %s" % [start, body.position, core_start, core])
	func _bodies() -> Dictionary:
		var result: Dictionary = {}
		for vehicle in vehicles:
			result[vehicle.get_instance_id()] = {"vehicle":vehicle,"position":Vector2(vehicle.lane_position * LANE_WIDTH, vehicle.y),"half":Vector2(vehicle.half_width, vehicle.half_length),"moving":vehicle.change_started,"speed":vehicle.actual_world_speed,"lane_position":vehicle.lane_position}
		return result
	func _cores() -> Dictionary:
		var result: Dictionary = {}
		if lane_events.state != lane_events.State.IDLE:
			for lane in lane_events._closed_lanes:
				result[lane] = Vector2(lane * LANE_WIDTH, lane_events._core_y())
		return result
	func _note(message: String) -> void:
		if contact.is_empty():
			contact = "substep=%d %s" % [observed_substeps, message]
	static func swept_contact(from: Vector2, to: Vector2, half: Vector2) -> bool:
		# Intersect the two open slab time intervals, not swept bounding boxes.
		var enter := 0.0
		var leave := 1.0
		for axis in range(2):
			var velocity := to[axis] - from[axis]
			if absf(velocity) < 0.000000001:
				if absf(from[axis]) >= half[axis]:
					return false
			else:
				var first := (-half[axis] - from[axis]) / velocity
				var second := (half[axis] - from[axis]) / velocity
				enter = maxf(enter, minf(first, second))
				leave = minf(leave, maxf(first, second))
		return enter < leave and leave > 0.0 and enter < 1.0

func _init() -> void:
	_check(ObservedTraffic.swept_contact(Vector2(-100, 0), Vector2(100, 0), Vector2(10, 10)), "oracle detects midstep crossing with clear endpoints")
	_check(not ObservedTraffic.swept_contact(Vector2(-100, 100), Vector2(100, 0), Vector2(10, 10)), "oracle rejects disjoint-axis corner false positive")
	for delta in STEPS:
		for scenario in ["same_gap", "head_on_blocked", "head_on_open", "core_single", "core_queue", "core_birth_blocked", "core_birth_safe"]:
			_case(scenario, delta)
	print("RESERVATION_CHECKS_COMPLETE failures=%d" % failures)
	print("TEST_COMPLETE test_product_traffic_reservations.gd")
	quit(0 if failures == 0 else 1)

func _case(scenario: String, delta: float) -> void:
	var traffic := ObservedTraffic.new(316)
	var definitions: Array = []
	match scenario:
		"same_gap": definitions = [[SIGNAL, 0, 150.0, 200.0, 1], [SIGNAL, 2, 300.0, 200.0, 1]]
		"head_on_blocked": definitions = [[SIGNAL, 0, 150.0, 200.0, 1], [SIGNAL, 1, 300.0, 200.0, 0]]
		"head_on_open": definitions = [[SIGNAL, 0, 100.0, 200.0, 1], [SIGNAL, 1, 440.0, 200.0, 0]]
		"core_single": definitions = [[STEADY, 0, 200.0, 200.0, 0]]
		"core_queue": definitions = [[STEADY, 0, 200.0, 200.0, 0], [TRUCK, 0, 600.0, 144.0, 0]]
		# NPCs are legal before the core exists; generating it here would cover them.
		"core_birth_blocked": definitions = [[STEADY, 0, -600.0, 180.0, 0], [STEADY, 2, -600.0, 180.0, 2]]
		"core_birth_safe": definitions = [[STEADY, 0, 200.0, 200.0, 0], [STEADY, 2, 200.0, 200.0, 2]]
	var actors: Array = []
	for definition in definitions:
		actors.append(traffic.acquire_vehicle(definition[0], definition[1], definition[2], definition[3]))
	var baseline: Array = []
	for reverse_order in [false, true]:
		# Restore the SAME objects/IDs, so array order is the only difference.
		traffic.reset(316)
		traffic._pool.clear()
		traffic._spawn_cooldown = 1000.0
		traffic.set_difficulty_stage(1)
		traffic.lane_events.enabled = scenario.begins_with("core_")
		traffic.contact = ""
		traffic.observed_substeps = 0
		traffic.warned.clear()
		traffic.started.clear()
		traffic.completed.clear()
		traffic.minimum_speed = INF
		traffic.core_visible = false
		for index in actors.size():
			var definition: Array = definitions[index]
			actors[index].configure(definition[0], definition[1], definition[2], definition[4], 0, definition[3])
		traffic.vehicles.assign(actors)
		if reverse_order:
			traffic.vehicles.reverse()
		if scenario in ["core_single", "core_queue"]:
			traffic.lane_events.begin_warning(0)
		elif scenario.begins_with("core_birth_"):
			traffic.lane_events._cooldown_remaining = 0.0
		for index in actors.size():
			var actor = actors[index]
			if not scenario.begins_with("core_"):
				_check(actor.lane_change_enabled and actor.target_lane != actor.lane and actor.y >= 40.0 and actor.y <= 720.0 - actor.half_length, "initial opposing/competing intents are enabled and visible")
			for other_index in range(index + 1, actors.size()):
				var other = actors[other_index]
				var relative := Vector2((actor.lane_position - other.lane_position) * LANE_WIDTH, actor.y - other.y)
				_check(not ObservedTraffic.swept_contact(relative, relative, Vector2(actor.half_width + other.half_width, actor.half_length + other.half_length)), "initial NPC rectangles are disjoint")
			if scenario in ["core_single", "core_queue"]:
				var initial_gap: float = actor.y - traffic.lane_events._core_y() - actor.half_length - 20.0
				var stopping_distance: float = (actor.actual_world_speed * actor.actual_world_speed / 840.0 + actor.actual_world_speed * 0.25) * Config.ROAD_SCROLL_MULTIPLIER
				_check(initial_gap > stopping_distance, "initial core approach has finite stopping room")
		var trace: Array = []
		for step in range(ceili(6.0 / delta)):
			traffic.tick(delta, 180.0 if scenario.begins_with("core_") else 200.0, 2 if scenario in ["core_single", "core_queue"] else 1)
			var sample: Array = []
			for actor in actors:
				sample.append([actor.lane_position, actor.y, actor.actual_world_speed, actor.warning_started, actor.change_started, traffic.vehicles.has(actor)])
			trace.append(sample)
		_check(traffic.contact.is_empty(), "%s dt=%s reverse=%s %s" % [scenario, delta, reverse_order, traffic.contact])
		_check(traffic.observed_substeps >= ceili(6.0 / delta), "observe every real substep")
		match scenario:
			"same_gap": _check(traffic.warned.size() == 1 and traffic.completed.size() == 1, "one of two competing same-gap intents visibly warns and completes")
			"head_on_blocked": _check(traffic.started.is_empty() and actors[0].lane == 0 and actors[1].lane == 1, "unsafe head-on intents must not start")
			"head_on_open": _check(traffic.warned.size() == 2 and traffic.completed.size() == 2, "safe separated opposing changes both visibly complete")
			"core_birth_blocked": _check(traffic.lane_events.event_history().contains("cancelled:") and not traffic.core_visible and traffic.vehicles.size() == actors.size() and is_equal_approx(traffic.minimum_speed, 180.0), "new core covering existing NPCs must be cancelled, not masked by braking/deletion")
			_: _check(traffic.core_visible and traffic.minimum_speed < 1.0, "safe core/queue exposes visible core and finite braking to wait")
		if reverse_order:
			_check(trace == baseline, "same-object reverse array must preserve all sampled outcomes: %s dt=%s" % [scenario, delta])
		else:
			baseline = trace
		print("RESERVATION_CASE ", JSON.stringify({"case":scenario,"dt":delta,"reverse":reverse_order,"substeps":traffic.observed_substeps,"warned":traffic.warned.size(),"started":traffic.started.size(),"completed":traffic.completed.size(),"core_visible":traffic.core_visible,"minimum_speed":traffic.minimum_speed,"contact":traffic.contact}))

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("RESERVATION_FAIL " + message)
