extends "res://scripts/tests/ProductTrafficMatrix.gd"
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var cases := build_cases()
	_check(cases.size() == 1080,"all 4x6x3x5x3 cases are generated")
	var unique: Dictionary = {}
	var configurations: Dictionary = {}
	for sample in cases:
		unique[sample.case_id] = true
		configurations["%s/%s/%d" % [sample.track_id,sample.vehicle_id,sample.difficulty_index]] = int(configurations.get("%s/%s/%d" % [sample.track_id,sample.vehicle_id,sample.difficulty_index],0))+1
	_check(unique.size() == 1080,"IDs are unique")
	_check(configurations.size() == 72 and configurations.values().all(func(count): return count == 15),"each real configuration receives all fifteen trajectories/seeds")
	var partition: Dictionary = {}
	var shards_complete := true
	for shard in SHARDS:
		var selected := select_cases(PackedStringArray(["--shard",str(shard)]))
		shards_complete = shards_complete and selected.size() == 60
		for sample in selected:
			if partition.has(sample.case_id): shards_complete = false
			partition[sample.case_id] = true
	_check(shards_complete and partition.size() == 1080,"all eighteen disjoint shards cover exactly the full denominator")
	_check(select_cases(PackedStringArray()).size() == 1080,"only explicit empty arguments select full batch")
	_check(select_cases(PackedStringArray(["--pilot"])).size() == 5,"bounded representative pilot selection is exactly five cases")
	for arguments in [PackedStringArray(["--shard","-1"]),PackedStringArray(["--shard","18"]),PackedStringArray(["--shard","x"]),PackedStringArray(["--pilot","--shard","0"]),PackedStringArray(["--unknown"])]:
		_check(select_cases(arguments).is_empty(),"invalid arguments cannot silently launch whole matrix")
	var definition := {"track_id":"sunrise_express","vehicle_id":"comet_rs","difficulty_index":2,"run_seed":618,"trajectory":"accelerate",
		"case_id":"sunrise_express/comet_rs/difficulty2/accelerate/seed618"}
	var setup := setup_case(definition)
	var single := select_cases(PackedStringArray(["--case",definition.case_id]))
	_check(single.size() == 1 and single[0] == definition,"exact case selection reproduces one real configuration")
	_check(select_cases(PackedStringArray(["--case","missing"])).is_empty(),"unknown case selection never becomes a full batch")
	_check(not setup.is_empty(),"selected real config creates actual controllers")
	if not setup.is_empty():
		_check(setup.drive.max_speed == 859.0 and setup.drive.acceleration == 224.0 and setup.drive.braking == 378.0,"chosen Comet world motion parameters are applied")
		_check(absf(setup.drive.steering_speed-477.36) < 0.00000001 and setup.drive.player_half_width == 30.0,"track and vehicle steering plus real player width applied")
		_check(setup.traffic.track_pattern == &"express_fast" and setup.traffic.spawn_interval_multiplier == 0.85 and setup.traffic.random_lane_change_probability == 0.34,"track and actual hard traffic rules applied")
		var row := sample_case(definition,0.25)
		_check(row.get("frames",0) == 15 and row.get("internal_steps",0) == 15,"sample actually runs fifteen observed production substeps")
		_check(absf(float(row.get("final_speed",0.0))-336.0) < 0.00001,"actual acceleration differs from baseline Pulse rather than label only")
		_check(row.get("independent_issues",-1) == 0,"small natural sample remains legal")
		_check(row.get("runtime_config",{}).get("maximum_speed",0.0) == 859.0,"evidence records actual selected controller rather than generic config")
	var invalid := definition.duplicate()
	invalid.vehicle_id = "unknown"
	_check(setup_case(invalid).is_empty(),"unknown car never falls back to Pulse in evidence")
	var mislabeled := definition.duplicate()
	mislabeled.case_id = "incorrect-label"
	_check(setup_case(mislabeled).is_empty(),"case label must agree with actual configuration")
	var floating_seed := definition.duplicate()
	floating_seed.run_seed = 618.0
	_check(setup_case(floating_seed).is_empty(),"seed metadata must be an integer rather than silently coerced")
	var missing_field := definition.duplicate()
	missing_field.erase("run_seed")
	_check(setup_case(missing_field).is_empty(),"incomplete configuration has no fallback")
	_check(sample_case(definition,0.0).get("error","") == "invalid_budget","invalid budget is not success")
	_check(sample_case(definition,0.001).get("error","") == "invalid_budget","zero rounded frames cannot masquerade as an actual sample")
	_check(sample_case(definition,INF).get("error","") == "invalid_budget","nonfinite budget rejects before simulation")
	_check(sample_case(definition,121.0).get("error","") == "invalid_budget","sample budget cannot exceed the frozen 120 seconds")
	for failure in failures: push_error("MATRIX_SELF_CHECK "+failure)
	print("MATRIX_SELF_CHECK checks=%d failures=%d" % [checks,failures.size()])
	print("TEST_COMPLETE test_product_traffic_matrix.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
