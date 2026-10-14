extends SceneTree
const Contract = preload("res://scripts/tests/SoakContract.gd")
var failures: Array[String] = []

func _init() -> void:
	InputMap.add_action("soak_forward_fixture")
	var binding := InputEventKey.new()
	binding.keycode = KEY_W
	InputMap.action_add_event("soak_forward_fixture", binding)
	var press: InputEventKey = Contract.key_event(KEY_W,true)
	_check(press.physical_keycode == KEY_W and press.keycode == KEY_W and press.is_action_pressed("soak_forward_fixture"), "Driver event matches actual logical key bindings as well as physical identity")
	InputMap.erase_action("soak_forward_fixture")
	_check(Contract.moving_frame(true,100.0,101.0,0.016), "Moving real frame supplies driving time")
	_check(not Contract.moving_frame(true,100.0,100.0,0.016), "Stopped RUNNING phase supplies no driving time")
	_check(not Contract.moving_frame(true,100.0,101.0,10.0), "Suspend gap supplies no driving time")
	_check(not Contract.moving_frame(false,100.0,101.0,0.016), "Menu phase supplies no driving time")
	_check(Contract.throttle_held(false,400.0,760.0), "Low speed requests acceleration")
	_check(not Contract.throttle_held(true,600.0,760.0), "High speed releases acceleration")
	_check(Contract.throttle_held(true,530.0,760.0) and not Contract.throttle_held(false,530.0,760.0), "Cruise hysteresis avoids per-frame accidental double taps")
	var valid := {"wall_seconds":1900.0,"driving_wall_seconds":1800.0,"returns":20,"outcomes":20,
		"tracks":4,"cars":6,"difficulties":3,"source_stable":true,"errors":[],"title_node_drift":0}
	_check(Contract.missing_coverage(valid).is_empty(), "Complete real-time coverage is accepted")
	for field in ["wall_seconds","driving_wall_seconds","returns","outcomes","tracks","cars","difficulties"]:
		var incomplete := valid.duplicate(true)
		incomplete[field] = 0
		_check(not Contract.missing_coverage(incomplete).is_empty(), "Missing " + field + " cannot pass")
	var changed := valid.duplicate(true)
	changed.source_stable = false
	_check(not Contract.missing_coverage(changed).is_empty(), "Changed production source cannot pass")
	var idle := valid.duplicate(true)
	idle.wall_seconds = 2400.0
	idle.driving_wall_seconds = 0
	_check(not Contract.missing_coverage(idle).is_empty(), "Long idle title time is not driving soak")
	var leak := valid.duplicate(true)
	leak.title_node_drift = 8
	_check(not Contract.missing_coverage(leak).is_empty(), "Retained title nodes fail")
	var errors := valid.duplicate(true)
	errors.errors = ["overlap"]
	_check(not Contract.missing_coverage(errors).is_empty(), "Runtime oracle failure cannot pass")
	print("SOAK_CONTRACT failures=", failures.size())
	print("TEST_COMPLETE test_product_soak_contract.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message); push_error(message)
