extends SceneTree
const Motion = preload("res://tests/support/traffic_motion_audit.gd")
const DT := 1.0/60.0
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	var before := _body(200.0,0.0,0.0,0)
	var after := _end(before,DT,300.0)
	_check(_audit(before,after).is_empty(),"unchanged absolute speed follows exact camera-relative displacement")
	for boundary in [140.0,-420.0]:
		after = _end(before,DT,300.0,boundary*DT)
		_check(_audit(before,after).is_empty(),"exact world acceleration/braking boundary is legal")
		after = _end(before,DT,300.0,(boundary+signf(boundary)*0.001)*DT)
		_check(_has(_audit(before,after),"world_acceleration" if boundary > 0.0 else "world_braking"),"strictly excessive world speed change is rejected")
	for kind in [0,1,2,3]:
		before = _body(200.0,0.0,0.0,kind)
		var acceleration := 360.0 if kind == 2 else 140.0
		after = _end(before,DT,300.0,acceleration*DT)
		_check(_audit(before,after).is_empty(),"exact kind-specific acceleration accepted for kind %d" % kind)
		after = _end(before,DT,300.0,(acceleration+0.001)*DT)
		_check(_has(_audit(before,after),"world_acceleration"),"excessive kind-specific acceleration rejected for kind %d" % kind)
		var rate := 3.4 if kind == 2 else 2.4
		for direction in [-1.0,1.0]:
			after = _end(before,DT,300.0)
			after.lane_position = direction*rate*DT
			_check(_audit(before,after).is_empty(),"both exact lateral boundaries accepted for kind %d" % kind)
			after.lane_position += direction*0.00001
			_check(_has(_audit(before,after),"lateral_rate"),"excessive lateral movement rejected for kind %d" % kind)
	before = _body(200.0,0.0,0.0,0)
	after = _end(before,DT,300.0)
	after.y += 0.1
	_check(_has(_audit(before,after),"longitudinal_displacement"),"longitudinal position correction cannot hide as finite world speed")
	for field in ["speed","cruise_speed","lane_position","y"]:
		after = _end(before,DT,300.0)
		after[field] = NAN
		_check(_has(_audit(before,after),"invalid_motion"),"nonfinite scalar %s rejected" % field)
	after = _end(before,DT,300.0)
	after.speed = -0.1
	_check(_has(_audit(before,after),"invalid_motion"),"negative actual world speed rejected")
	after = _end(before,DT,300.0)
	after.cruise_speed += 20.0
	_check(_has(_audit(before,after),"cruise_changed"),"fixed desired speed cannot follow camera changes")
	after = _end(before,DT,300.0)
	after.generation += 1
	_check(_has(_audit(before,after),"motion_identity_changed"),"pool generations cannot share a motion interval")
	_check(_has(Motion.audit_step({"v":before},{},DT,300.0,1.15),"motion_missing_final"),"retired motion requires final position and speed")
	_check(_has(Motion.audit_step({}, {"v":after},DT,300.0,1.15),"motion_missing_start"),"birth requires true premovement snapshot")
	_check(_has(Motion.audit_step({}, {},NAN,300.0,1.15),"invalid_motion_interval"),"invalid time cannot pass with no bodies")
	_check(_has(Motion.audit_step({}, {},DT,INF,1.15),"invalid_motion_interval"),"invalid camera speed rejected")
	_check(Motion.audit_frame({"v":3.4*0.25},{"v":2},0.25).is_empty(),"exact total 250ms budget accepted")
	_check(Motion.audit_frame({"v":3.4*0.25+0.000099},{"v":2},0.25).is_empty(),"one whole-frame tolerance is allowed")
	_check(_has(Motion.audit_frame({"v":3.4*0.25+15.0*0.00005},{"v":2},0.25),"frame_lateral_budget"),"fifteen repeated substep allowances cannot pass as one whole-frame allowance")
	_check(_has(Motion.audit_frame({"v":2.4*0.25+0.00011},{"v":0},0.25),"frame_lateral_budget"),"normal vehicle must not borrow fast lateral limit")
	_check(_has(Motion.audit_frame({"v":NAN},{"v":0},0.25),"invalid_frame_travel"),"nonfinite accumulated travel rejected")
	for failure in failures: push_error("MOTION_ORACLE_SELF_CHECK "+failure)
	print("MOTION_ORACLE_SELF_CHECK checks=%d failures=%d" % [checks,failures.size()])
	print("TEST_COMPLETE test_product_traffic_motion_oracle.gd")
	quit(0 if failures.is_empty() else 1)

func _body(speed: float, lane_position: float, y: float, kind: int) -> Dictionary:
	return {"id":1,"generation":1,"speed":speed,"cruise_speed":200.0,"lane_position":lane_position,"y":y,"kind":kind}

func _end(before: Dictionary, delta: float, player_speed: float, change: float = 0.0) -> Dictionary:
	var after := before.duplicate()
	after.speed += change
	after.y += (player_speed-after.speed)*1.15*delta
	return after

func _audit(before: Dictionary, after: Dictionary) -> Array[String]:
	return Motion.audit_step({"v":before},{"v":after},DT,300.0,1.15)

func _has(issues: Array[String], category: String) -> bool:
	return issues.any(func(issue): return issue.begins_with(category))

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
