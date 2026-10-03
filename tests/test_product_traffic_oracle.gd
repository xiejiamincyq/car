extends SceneTree

const Oracle = preload("res://tests/support/traffic_audit_geometry.gd")
var failures: Array[String] = []
var attempted := 0

func _init() -> void:
	# Expected results are explicit mathematical counterexamples, not calls to
	# the production overlap/reservation/following detectors.
	var examples := [
		[-100.0,0.0,100.0,0.0,10.0,10.0,true,"midstep pass with both endpoints clear"],
		[-100.0,100.0,100.0,0.0,10.0,10.0,false,"axis intervals do not intersect"],
		[0.0,0.0,0.0,0.0,10.0,10.0,true,"stationary body penetration"],
		[-100.0,10.0,100.0,10.0,10.0,10.0,false,"tangent side does not penetrate"],
		[10.0,0.0,20.0,0.0,10.0,10.0,false,"start touching and leave"],
		[20.0,0.0,10.0,0.0,10.0,10.0,false,"finish touching only"],
		[-20.0,0.0,-9.0,0.0,10.0,10.0,true,"finish inside"],
		[-10.0,0.0,10.0,0.0,10.0,10.0,true,"boundary endpoints but interior penetration"],
		[-20.0,-20.0,-10.0,-10.0,10.0,10.0,false,"finish corner touch only"],
		[-20.0,-20.0,20.0,20.0,10.0,10.0,true,"diagonal through corner interior"],
		[-20.0,-20.0,-11.0,20.0,10.0,10.0,false,"outside lateral axis throughout"],
		[-20.0,40.0000001,20.0,0.0,10.0,10.0,false,"tiny positive gap between axis contact intervals"],
		[-100000000.0,0.0,100000000.0,0.0,0.00001,10.0,true,"double scalar narrow interior crossing"],
	]
	for item in examples:
		_check(Oracle.swept_overlap(item[0],item[1],item[2],item[3],item[4],item[5]) == item[6],item[7])
		_check(Oracle.swept_overlap(item[2],item[3],item[0],item[1],item[4],item[5]) == item[6],"time reverse: " + item[7])
	var first := {"id":1,"generation":1,"x":-100.0,"y":0.0,"half_x":5.0,"half_y":5.0}
	var after := first.duplicate()
	after.x = 100.0
	var second := {"id":2,"generation":1,"x":0.0,"y":0.0,"half_x":5.0,"half_y":5.0}
	_check(Oracle.body_sweep(first,after,second,second),"actual same-generation body crossing")
	after.generation = 2
	_check(not Oracle.body_sweep(first,after,second,second),"pool reuse is not a physical sweep from retired location")
	after.x = 0.0
	_check(Oracle.body_overlap(after,second),"newborn endpoint overlap must still be detected separately")
	_check(Oracle.retirement(first,{},720.0) == "missing_final_snapshot","missing final position is unknown, not a valid recycle")
	_check(Oracle.retirement(first,after,720.0) == "identity_mismatch","reused reference cannot prove old object's safe retirement")
	after.generation = 1
	_check(Oracle.retirement(first,after,720.0) == "visible_removed","retirement with body still visible is unsafe")
	after.y = -5.0
	_check(Oracle.visible(after,720.0),"top boundary body touching screen remains visible")
	after.y = -5.0000001
	_check(not Oracle.visible(after,720.0),"double coordinate just outside top is not visible")
	_check(Oracle.retirement(first,after,720.0) == "offscreen_recycled","complete final body outside top allows recycle")
	after.y = 725.0
	_check(Oracle.visible(after,720.0),"bottom boundary body touching screen remains visible")
	after.y = 725.0000001
	_check(not Oracle.visible(after,720.0),"double coordinate just outside bottom is not visible")
	_check_step_world()
	for failure in failures: push_error("ORACLE_SELF_CHECK " + failure)
	print("ORACLE_SELF_CHECK attempted=%d failures=%d" % [attempted,failures.size()])
	print("TEST_COMPLETE test_product_traffic_oracle.gd")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	attempted += 1
	if not condition: failures.append(message)

func _check_step_world() -> void:
	var first := {"id":1,"generation":1,"x":-100.0,"y":0.0,"half_x":5.0,"half_y":5.0}
	var final := first.duplicate()
	final.x = 100.0
	var second := {"id":2,"generation":1,"x":0.0,"y":0.0,"half_x":5.0,"half_y":5.0}
	_check(Oracle.audit_step({"1/1":first,"2/1":second},{"1/1":final,"2/1":second},{},{},720.0).has("sweep_overlap:1/1:2/1"),"world catches interior crossing independently")
	_check(Oracle.audit_step({"1/1":first},{},{},{},720.0).has("missing_final_snapshot:1/1"),"lost entity without retirement cannot pass")
	_check(Oracle.audit_step({"1/1":first},{},{},{"1/1":final},720.0).has("visible_removed:1/1"),"world rejects visible retirement")
	var born := second.duplicate()
	born.x = -100.0
	_check(Oracle.audit_step({"1/1":first},{"1/1":first,"2/1":second},{"2/1":born},{},720.0).has("birth_overlap:1/1:2/1"),"birth penetration is checked before movement separates bodies")
	_check(Oracle.audit_step({"1/1":first},{"1/1":first,"2/1":second},{},{},720.0).has("missing_birth_snapshot:2/1"),"new entity without birth position cannot pass")
	var reused := final.duplicate()
	reused.generation = 2
	_check(Oracle.audit_step({"1/1":first},{"1/1":reused},{},{},720.0).has("identity_mismatch:1/1"),"reused reference under old key cannot pass")
	final.y = -10.0
	_check(Oracle.audit_step({"1/1":first},{},{},{"1/1":final},720.0).is_empty(),"complete offscreen retirement is valid")
	_check(Oracle.audit_step({"1/1":first},{"1/2":reused},{"1/2":reused},{"1/1":final},720.0).has("overlapping_generations:1"),"two generations in one step require finer lifetime evidence")
	_check(Oracle.audit_step({},{"1/2":reused},{"1/2":reused},{},720.0).is_empty(),"reuse born in a subsequent step has no sweep from old retired location")
	final.x = -100.0
	final.y = 0.0
	_check(Oracle.audit_step({"1/1":first},{"1/1":final,"2/1":second},{"2/1":second},{},720.0).is_empty(),"stationary separated bodies and legitimate birth pass")
	var exit_body := first.duplicate()
	exit_body.x = 100.0
	exit_body.y = -10.0
	_check(Oracle.audit_step({"1/1":first,"2/1":second},{"2/1":second},{},{"1/1":exit_body},720.0).has("sweep_overlap:1/1:2/1"),"retirement endpoint is included in last movement sweep")
	var malformed := first.duplicate()
	malformed.x = NAN
	_check(Oracle.audit_step({"1/1":first},{"1/1":malformed},{},{},720.0).has("invalid_snapshot:1/1"),"nonfinite coordinate is unknown rather than a clear sweep")
	malformed = first.duplicate()
	malformed.half_x = 0.0
	_check(Oracle.audit_step({"1/1":first},{"1/1":malformed},{},{},720.0).has("invalid_snapshot:1/1"),"zero body extent cannot prove safety")
	malformed.half_x = 6.0
	_check(Oracle.audit_step({"1/1":first},{"1/1":malformed},{},{},720.0).has("body_size_changed:1/1"),"constant-extent sweep must reject changing dimensions")
	final.y = -10.0
	_check(Oracle.audit_step({"1/1":first},{"1/1":final},{},{"1/1":final},720.0).has("contradictory_lifecycle:1/1"),"entity cannot be live and retired at the same time")
	_check(Oracle.audit_step({"1/1":first},{"1/1":first},{"1/1":first},{},720.0).has("duplicate_birth:1/1"),"existing same-generation entity cannot have a second birth")
