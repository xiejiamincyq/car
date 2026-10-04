extends "res://scripts/tests/NaturalFallbackRecoveryAudit.gd"

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var failures: Array[String] = []
	if not _selfcheck(): failures.append("original physical, input and invalid-prefix checks")
	var drive = Drive.new(800.0,800.0,220.0,420.0,500.0,390.0,30.0)
	var frames: Array = []
	for index in 240: frames.append({"dt":STEP,"speed":800.0,"bodies":[],"status":"valid"})
	for initial_x in [-200.0,200.0]:
		var center := _plan_center_trace(frames,drive,100.0,initial_x)
		if center.status != "candidate" or absf(center.xs.back()) > 0.0000001:
			failures.append("center preference uses real bounded steering, never a position snap")
	var blocked := frames.duplicate(true)
	blocked[0].bodies = [{"x0":0.0,"x1":0.0,"y0":592.0,"y1":592.0,"half_x":400.0,"half_y":42.0}]
	if _plan_trace(blocked,drive).status != "unverified": failures.append("physical full-width blocker cannot pass")
	blocked[239].speed = INF
	if _plan_trace(blocked,drive).status != "invalid": failures.append("early search failure must not mask invalid later physics")
	var clear_plan := _plan_trace(frames,drive)
	if clear_plan.status != "candidate" or clear_plan.has("intent_fallback_window"):
		failures.append("clear original route does not trigger heuristic recovery")

	var frame := {"status":"valid","dt":STEP,"speed":800.0,"bodies":[
		{"family":"npc","identity":"npc/1","x0":-223.6,"x1":-223.6,"y0":525.14125,"y1":525.14125,"half_x":32.3666666716667,"half_y":48.12375}],
		"lane_intents":{"npc/1":{"from_x":-260.0,"to_x":0.0}}}
	var original := frame.duplicate(true)
	var result := planning_frames([frame])
	var geometry := {"half_x":30.0,"half_y":30.0,"y":592.0}
	if result.status != "valid": failures.append("valid intent is available as a planning preference")
	else:
		if PathOracle._clear(geometry,result.frames[0],-286.11,-286.11): failures.append("cannot assume pending NPC vacates original lane")
		if PathOracle._clear(geometry,result.frames[0],0.0,0.0): failures.append("announced target remains reserved for planning")
		if not PathOracle._clear(geometry,result.frames[0],-340.0,-340.0): failures.append("genuine shoulder clearance remains available")
	if frame != original: failures.append("planning cannot mutate actual collision geometry")
	for target in [INF,"0",false,65.0,520.0]:
		var malformed := frame.duplicate(true)
		malformed.lane_intents["npc/1"].to_x = target
		if planning_frames([malformed]).status != "invalid": failures.append("invalid or noncanonical intent target rejected")
	var orphan := frame.duplicate(true)
	orphan.lane_intents["missing/1"] = {"from_x":0.0,"to_x":260.0}
	if planning_frames([orphan]).status != "invalid": failures.append("orphan intent is not silently discarded")
	var traffic = IntentTraffic.new(611)
	var waiting = traffic.acquire_vehicle(1,0,50.0)
	traffic.vehicles.append(waiting)
	if not traffic._intents().is_empty(): failures.append("unannounced plan cannot reserve a lane")
	waiting.warning_started = true
	if traffic._intents().size() != 1: failures.append("announced plan reserves its original and target lanes")

	# A selected alternate cannot reset to the original forecast on repair two.
	var controls: Array = []
	var xs: Array = [0.0]
	for index in 240:
		var input := 1.0 if index == 0 else 0.0
		drive.step(STEP,1.0,0.0,input)
		controls.append(input)
		xs.append(drive.lateral_position)
	_plan_trace(frames,drive)
	_alternate_active = true
	_repair_calls = 1
	var actual_frames := frames.duplicate(true)
	actual_frames[180].bodies = [{"x0":0.0,"x1":0.0,"y0":592.0,"y1":592.0,"half_x":25.0,"half_y":42.0}]
	var repaired := _repair_from_replay({"status":"valid","frames":actual_frames,"drive":drive,"xs":xs},
		{"status":"candidate","controls":controls,"xs":xs})
	if repaired.status != "candidate": failures.append("valid actual feedback creates a bounded physical repair")
	elif repaired.controls.slice(0,60) != controls.slice(0,60) or repaired.xs.slice(0,61) != xs.slice(0,61):
		failures.append("active alternate preserves the sixty-step verified actual prefix")
	if repaired.get("selection_reason","") == "two_real_feedback_misses_alternate_original_forecast":
		failures.append("alternate cannot be selected twice")
	print("NATURAL_RECOVERY_CHECKS_COMPLETE ",JSON.stringify({"failures":failures,"scope":"bounded test-only planner; no game rule changes or new 1080 batch claim"}))
	print("TEST_COMPLETE test_product_natural_recovery.gd")
	quit(0 if failures.is_empty() else 1)
