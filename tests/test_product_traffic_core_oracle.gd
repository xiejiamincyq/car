extends SceneTree
const Core = preload("res://tests/support/traffic_core_audit.gd")
var failures: Array[String] = []

func _init() -> void:
	var n0 := _body(1,1,0.0,-100.0,25.0,42.0)
	var n1 := _body(1,1,0.0,100.0,25.0,42.0)
	var core := _body(1,1,0.0,0.0,100.0,34.0)
	var issues := Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":core})
	_check(issues.has("core_sweep_overlap:n:c"),"interior crossing of a core is detected even with clear endpoints")
	_check(not issues.has("core_initial_overlap:n:c") and not issues.has("core_endpoint_overlap:n:c"),"fixture actually has both endpoints clear")
	var shifted := core.duplicate()
	shifted.y = 200.0
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":shifted}).is_empty(),"equal screen scroll without relative contact is safe")
	n0.x = 125.0
	n1.x = 125.0
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":core}).is_empty(),"exact side tangency is not penetration")
	n0.x = 124.999999
	n1.x = 124.999999
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":core}).has("core_sweep_overlap:n:c"),"thin positive contact interval is preserved")
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{},{"c":core}).has("core_missing_start:c"),"core birth start evidence cannot be silently invented")
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{}).has("core_missing_final:c"),"core retirement end evidence is required")
	var changed := core.duplicate()
	changed.generation = 2
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":changed}).has("core_identity_changed:c"),"same lane in a new event is not a continuous old core")
	changed = core.duplicate()
	changed.y = NAN
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":changed}).has("core_invalid_snapshot:c"),"invalid scalar geometry cannot pass")
	changed = core.duplicate()
	changed.half_y = 50.0
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":changed}).has("core_size_changed:c"),"changing collision dimensions are rejected")
	_check(Core.audit_cross_step({"n":n0},{"n":n1},{},{}).is_empty(),"no cores introduces no artificial obstacle")
	n0.x = 0.0
	n1.x = 0.0
	n0.y = 0.0
	issues = Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":core})
	_check(issues.has("core_initial_overlap:n:c"),"overlapping birth or initial state is diagnosed")
	n1.y = 0.0
	issues = Core.audit_cross_step({"n":n0},{"n":n1},{"c":core},{"c":core})
	_check(issues.has("core_endpoint_overlap:n:c"),"actual endpoint overlap is diagnosed")
	for failure in failures: push_error("CORE_ORACLE_SELF_CHECK "+failure)
	print("CORE_ORACLE_SELF_CHECK failures=%d" % failures.size())
	print("TEST_COMPLETE test_product_traffic_core_oracle.gd")
	quit(0 if failures.is_empty() else 1)

func _body(id: int, generation: int, x: float, y: float, half_x: float, half_y: float) -> Dictionary:
	return {"id":id,"generation":generation,"x":x,"y":y,"half_x":half_x,"half_y":half_y}

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
