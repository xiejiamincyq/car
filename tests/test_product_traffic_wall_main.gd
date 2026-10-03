extends "res://scripts/tests/ProductHardSupplyAudit.gd"

func _run() -> void:
	root.size = Vector2i(1280,720)
	var exact_case := "sunrise_express/tidebreaker/brake_repass/seed2026"
	var source := _source_metadata()
	active_scenario = "brake_repass"
	_physical_forward(false)
	var row: Dictionary = await _sample_configuration(["sunrise_express","tidebreaker",2026],0,2,100.0,120.0,exact_case)
	_physical_forward(false)
	_check(missing_input_goals(active_scenario,row.input_observed).is_empty(),"actual braking and same-NPC repass occur in natural regression")
	_check(row.stop_reason == "clear" and row.terminal_frame_checked and row.distance >= row.runtime_config.finish_distance,
		"original natural fixture reaches genuine finish without injected supplies or discarded terminal frames")
	_check(_source_metadata() == source,"natural wall regression sources remain unchanged")
	print("WALL_MAIN_REGRESSION ",JSON.stringify({"case_id":exact_case,"seconds":row.seconds,"oracle_frames":row.oracle_frames,
		"stop_reason":row.stop_reason,"fuel":row.fuel,"repair":row.repair,"collisions":row.collisions,"input_observed":row.input_observed,
		"source":source,"failures":failures.size()}))
	for failure in failures: push_error("WALL_MAIN_REGRESSION " + failure)
	print("TEST_COMPLETE test_product_traffic_wall_main.gd")
	quit(0 if failures.is_empty() else 1)
