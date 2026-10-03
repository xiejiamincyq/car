extends SceneTree

const Audit = preload("res://scripts/tests/ProductHardSupplyAudit.gd")
var failures: Array[String] = []

func _init() -> void:
	var cases := Audit.build_cases()
	_check(cases.size() == 288, "4 tracks x6 actual cars x4 scenarios x3 frozen seeds")
	var identities := {}
	var pairs := {}
	for sample in cases:
		_check(not identities.has(sample.case_id), "every planned case ID is unique")
		identities[sample.case_id] = true
		_check(sample.difficulty_index == 2 and sample.budget_seconds == 120.0, "hard fixed120 budget")
		_check(sample.initial_hull_fixture == (30.0 if sample.scenario == "hull30" else 100.0), "only explicit damaged fixture changes initial hull")
		_check(not Audit.Tracks.get_by_id(StringName(sample.track_id)).is_empty() and not Audit.Cars.get_by_id(StringName(sample.vehicle_id)).is_empty(), "case refers to real catalog configurations")
		pairs[sample.track_id + "/" + sample.vehicle_id] = true
	_check(pairs.size() == 24, "no missing track/car combination")
	var empty := {"brake_deceleration_frames":0,"same_vehicle_repasses":0,"skip_outcome":"unseen","avoid_input_frames":0,
		"critical_frames":0,"repair_effective":0.0,"overdrive_activations":0,"overdrive_ended":false,"post_overdrive_brake_frames":0}
	for scenario in Audit.SCENARIOS:
		_check(not Audit.missing_input_goals(scenario, empty).is_empty(), "negative control: absent input cannot pass " + scenario)
	var observed := empty.duplicate()
	observed.brake_deceleration_frames = 1
	observed.same_vehicle_repasses = 1
	observed.skip_outcome = "recycled"
	observed.avoid_input_frames = 1
	observed.critical_frames = 1
	observed.repair_effective = 20.0
	observed.overdrive_activations = 1
	observed.overdrive_ended = true
	observed.post_overdrive_brake_frames = 1
	for scenario in Audit.SCENARIOS:
		_check(Audit.missing_input_goals(scenario, observed).is_empty(), "positive control for observed " + scenario)
	observed.same_vehicle_repasses = 0
	_check(Audit.missing_input_goals("brake_repass", observed).has("same_vehicle_repass"), "different NPC overtakes cannot prove a same-car repass")
	observed.skip_outcome = "collected"
	_check(Audit.missing_input_goals("skip_first_fuel", observed).has("deliberate_first_fuel_miss"), "collecting first fuel cannot count as deliberately missing it")
	_check(not Audit.suitable_repass_target(650.0,200.0,false,592.0,760.0), "already-behind NPC may recycle before finite braking catches it")
	_check(Audit.suitable_repass_target(480.0,200.0,false,592.0,760.0), "choose visible NPC still ahead before braking")
	_check(not Audit.suitable_repass_target(480.0,920.0,false,592.0,760.0), "cannot request catching an unobstructed faster overtaker")
	_check(not Audit.suitable_repass_target(480.0,200.0,true,592.0,760.0), "player impact cannot masquerade as a clean repass")
	observed.overdrive_ended = false
	_check(Audit.missing_input_goals("overdrive_brake",observed).has("actual_post_overdrive_braking"), "braking during active boost cannot prove braking after it ended")
	_check(Audit.select_cases(PackedStringArray(["--pilot"])).size() == 4, "pilot is only four declared representative rows")
	var shard_ids := {}
	for shard in range(12):
		var selected := Audit.select_cases(PackedStringArray(["--shard",str(shard)]))
		_check(selected.size() == 24, "each of12 shards has24 rows")
		for row in selected:
			_check(not shard_ids.has(row.case_id), "shards cannot silently duplicate another shard's rows")
			shard_ids[row.case_id] = true
	_check(shard_ids.size() == 288, "union of frozen shards covers every unique case")
	for invalid in [["--shard","-1"],["--shard","12"],["--shard","x"],["--unknown"]]:
		_check(Audit.select_cases(PackedStringArray(invalid)).is_empty(), "invalid selection is rejected, not silently a full run")
	for failure in failures: push_error("HARD_SUPPLY_SELF_CHECK " + failure)
	print("HARD_SUPPLY_SELF_CHECK failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_hard_supply_audit.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
