extends SceneTree
const Envelope = preload("res://tests/support/observed_player_path_traffic.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var cap := 3.4*260.0/60.0
	for delta_x in [-cap,-cap*0.5,0.0,cap*0.5,cap]:
		var frame := Envelope._frame_from_raw(_raw(delta_x),1.0/60.0,760.0)
		_check(frame.status == "valid","legal lateral budget yields valid envelope")
		var body: Dictionary = frame.bodies[0]
		_check(absf(body.half_x-25.0-cap*0.5) < 0.00000001,"envelope is the proven total-path budget, not extra budget plus endpoint span")
		for sample in 101:
			var position: float = (delta_x-cap)*0.5+sample*cap/100.0
			var path_length := absf(position)+absf(delta_x-position)
			if path_length <= cap+0.00000001:
				_check(absf(position-body.x0)+25.0 <= body.half_x+0.00000001,"every legal bent excursion and full NPC width stays in the envelope")
	_check(Envelope._frame_from_raw(_raw(cap+0.001),1.0/60.0,760.0).status == "invalid","over-budget endpoint is invalid, not a narrowed unsafe envelope")
	print("PATH_ENVELOPE_BUDGET_COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: print("PATH_ENVELOPE_BUDGET_FAIL "+failure)
	print("TEST_COMPLETE test_product_path_envelope_budget.gd")
	quit(0 if failures.is_empty() else 1)

func _raw(end_x: float) -> Dictionary:
	var before := {"id":1,"generation":1,"x":0.0,"y":592.0,"half_x":25.0,"half_y":42.0}
	var after := before.duplicate()
	after.x = end_x
	return {"npc_before":{"1/1":before},"npc_births":{},"npc_final":{"1/1":after},"core_before":{},"core_births":{},
		"core_final":{},"early_retired":{},"motion_cores":{},"retirement_reasons":{}}

func _check(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
