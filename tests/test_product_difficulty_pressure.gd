extends SceneTree
## Actual visible traffic and completed manoeuvres, not only config differences.
const Traffic = preload("res://scripts/traffic_director.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
const SEEDS := [611, 2026, 9001, 616, 618]
var failures: Array[String] = []
class MeasuredTraffic extends Traffic:
	var opportunities := 0
	var candidates := 0
	var priority_skips := 0
	func _spawn_next(speed: float, lane: int) -> void:
		opportunities += 1
		if fast_priority.needs_clearance_window(self): priority_skips += 1
		super._spawn_next(speed, lane)
	func _can_spawn_candidate(candidate, speed: float, lane: int) -> bool:
		candidates += 1
		return super._can_spawn_candidate(candidate, speed, lane)

func _init() -> void:
	var totals := [0.0, 0.0, 0.0]
	var completed := [0, 0, 0]
	for index in 3:
		var profile := Difficulty.for_index(index)
		var traffic := Traffic.new(611)
		traffic.configure_difficulty(profile)
		traffic.set_difficulty_stage(0)
		_check(traffic.lane_change_warning_duration() >= 0.45, "Visible NPC warning never falls below 450ms")
		if index == 2:
			_check(traffic._kind_schedule().has(Traffic.Kind.SIGNAL_CHANGE), "Hard must expose planned weaving in the opening sector")
			_check(traffic.maximum_kind_for_stage() == Traffic.Kind.SIGNAL_CHANGE, "Opening hard weaving must agree with the advertised kind range")
			var normal := Traffic.new(611)
			normal.configure_difficulty(Difficulty.for_index(1))
			_check(traffic.lane_change_warning_duration() <= normal.lane_change_warning_duration() * 0.8, "Hard reaction window is at least 20% shorter than standard")
		for seed_value in SEEDS:
			var result := _sample(seed_value, index)
			totals[index] += result.visible_seconds
			completed[index] += result.completed
	_check(totals[2] >= totals[1] * 1.35, "Actual hard ordinary traffic exposure must exceed standard by at least 35%")
	_check(completed[2] >= maxi(1, completed[1] * 2), "Hard must complete at least twice as many real lane changes as standard")
	print("DIFFICULTY_PRESSURE ", JSON.stringify({"seeds": SEEDS, "ordinary_visible_seconds": totals, "completed_lane_changes": completed, "failures": failures}))
	for failure in failures: push_error(failure)
	print("TEST_COMPLETE test_product_difficulty_pressure.gd")
	quit(0 if failures.is_empty() else 1)

func _sample(seed_value: int, index: int) -> Dictionary:
	var traffic := MeasuredTraffic.new(seed_value)
	traffic.configure_difficulty(Difficulty.for_index(index))
	var visible_seconds := 0.0
	var completed := 0
	var stage_visible := [0.0, 0.0, 0.0, 0.0]
	var construction_seconds := 0.0
	for step in 2700:
		traffic.set_difficulty_stage(mini(3, int(step / 675)))
		var before := {}
		for vehicle in traffic.vehicles:
			if vehicle.kind != Traffic.Kind.FAST_OVERTAKE and vehicle.change_started:
				before[vehicle.get_instance_id()] = {"generation": vehicle.motion_generation, "target": vehicle.target_lane}
		traffic.tick(1.0 / 60.0, 760.0, 1)
		_check(traffic.minimum_lane_gap == 180.0 and traffic.minimum_spawn_distance == 620.0, "Difficulty never weakens admission spacing or moves births into view")
		if traffic.lane_events.state != 0: construction_seconds += 1.0 / 60.0
		for vehicle in traffic.vehicles:
			if vehicle.kind == Traffic.Kind.FAST_OVERTAKE: continue
			if vehicle.y > 0.0 and vehicle.y < 720.0:
				visible_seconds += 1.0 / 60.0
				stage_visible[traffic.difficulty_stage] += 1.0 / 60.0
			var identity := vehicle.get_instance_id()
			if before.has(identity) and before[identity].generation == vehicle.motion_generation and not vehicle.change_started and is_equal_approx(vehicle.lane_position, float(before[identity].target)):
				completed += 1
		_check(not traffic.has_vehicle_overlap() and not traffic.has_full_lane_wall(), "Difficulty pressure preserves body and wall safety")
	var ordinary_since_fast := 0
	for birth in traffic.spawn_sequence().split("|", false):
		if int(birth.get_slice(":", 0)) == Traffic.Kind.FAST_OVERTAKE:
			_check(ordinary_since_fast >= int(Difficulty.for_index(index).ordinary_births_between_fast), "Hard red passes must be separated by actual ordinary births, not attempted births")
			ordinary_since_fast = 0
		else: ordinary_since_fast += 1
	print("PRESSURE_SAMPLE ", JSON.stringify({"seed": seed_value, "difficulty": index, "stages": stage_visible, "opportunities": traffic.opportunities, "candidates": traffic.candidates, "priority_skips": traffic.priority_skips, "construction_seconds": construction_seconds}))
	return {"visible_seconds": visible_seconds, "completed": completed}

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
