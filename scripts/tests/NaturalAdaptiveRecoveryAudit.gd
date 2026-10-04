extends "res://scripts/tests/ProductNaturalPathAudit.gd"

func _init() -> void:
	if OS.get_cmdline_user_args() == PackedStringArray(["--selfcheck"]):
		call_deferred("_run_center_selfcheck")
	elif OS.get_cmdline_user_args().size() == 2 and OS.get_cmdline_user_args()[0] == "--inspect-recording":
		call_deferred("_inspect_recording")
	else:
		call_deferred("_entry")

func _run_center_selfcheck() -> void:
	var failures: Array[String] = []
	if not super._selfcheck(): failures.append("original physical/input/invalid-prefix selfcheck")
	var drive = Drive.new(800.0,800.0,220.0,420.0,500.0,390.0,30.0)
	var frames: Array = []
	for index in 240: frames.append({"dt":STEP,"speed":800.0,"bodies":[],"status":"valid"})
	for initial_x in [-200.0, 200.0]:
		var candidate := _plan_center_trace(frames,drive,100.0,initial_x)
		if candidate.status != "candidate" or absf(candidate.xs.back()) > 0.0000001:
			failures.append("physically recenter from a nonzero clear-road start: " + str(initial_x))
		var trace := {"x0":initial_x,"y":592.0,"road_half":390.0,"half_x":30.0,"half_y":30.0,"steering_speed":500.0,"max_speed":800.0,"hull":100.0,"frames":frames.slice(0,120)}
		if candidate.status == "candidate" and not PathOracle.validate_path(trace,{"xs":candidate.xs.slice(0,121),"controls":candidate.controls.slice(0,120)}):
			failures.append("recenter first window must validate against real steering bounds")
	var blocked := frames.duplicate(true)
	for index in blocked.size():
		blocked[index].bodies = [{"x0":0.0,"x1":0.0,"y0":592.0,"y1":592.0,"half_x":80.0,"half_y":42.0}]
	var avoiding := _plan_center_trace(blocked,drive,100.0,200.0)
	if avoiding.status != "candidate": failures.append("blocked center retains valid side route, never forcibly recenters")
	elif avoiding.xs.min() <= 110.0: failures.append("blocked center never penetrated")
	print("CENTER_RECOVERY_SELFCHECK_COMPLETE ",JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _inspect_recording() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[1]))
	if data is not Dictionary or not data.has("row") or not data.has("forecast"):
		quit(2)
		return
	var canonical := select_route_cases(PackedStringArray(["--case",String(data.row.case_id)]))
	if canonical.size() != 1:
		quit(2)
		return
	var setup := setup_case(canonical[0])
	if setup.is_empty():
		quit(2)
		return
	var candidate := _plan_trace(data.forecast.frames,setup.drive,float(data.row.hull_fixture),float(data.forecast.xs[0]))
	print("CENTER_RECORDING_COMPLETE ",JSON.stringify({"case_id":data.row.case_id,"status":candidate.status,"controls":candidate.controls.size(),"xs":candidate.xs.size(),"failed_window":candidate.get("failed_window",-1),"scope":"recorded-forecast candidate only, not actual traffic feedback proof"}))
	quit(0 if candidate.status == "candidate" else 1)

func _plan_center_trace(frames: Array, drive, hull: float = 100.0, initial_x: float = 0.0) -> Dictionary:
	if frames.is_empty() or frames.size() > 7200: return {"status":"invalid","controls":[],"xs":[]}
	var controls: Array = []
	var xs: Array = [initial_x]
	var windows := 0
	var refinements := 0
	var hold_windows := 0
	var center_windows := 0
	for start in range(0,frames.size(),60):
		var chunk := frames.slice(start,mini(start+120,frames.size()))
		var trace := {"x0":xs.back(),"y":592.0,"road_half":drive.road_half_width,"half_x":drive.player_half_width,"half_y":30.0,
			"steering_speed":drive.steering_speed,"max_speed":drive.max_speed,"hull":hull,"frames":chunk}
		if not PathOracle._valid_trace(trace): return {"status":"invalid","controls":controls,"xs":xs}
		var path: Dictionary = {"status":"unverified","controls":[],"xs":[]}
		if absf(trace.x0) > 1.0:
			path = _center_path(trace)
			if path.status == "witness": center_windows += 1
		if path.status != "witness":
			var hold_controls: Array = []
			var hold_xs: Array = [trace.x0]
			for _index in chunk.size():
				hold_controls.append(0.0)
				hold_xs.append(trace.x0)
			path = {"status":"witness","controls":hold_controls,"xs":hold_xs}
			if PathOracle.validate_path(trace,path):
				hold_windows += 1
			else:
				path = PathOracle.find_path(trace)
		if path.status == "unverified":
			refinements += 1
			path = PathOracle.find_path(trace,[0.0,-1.0,-0.5,0.5,1.0])
		if path.status != "witness":
			return {"status":path.status,"controls":controls,"xs":xs,"windows":windows,"refinements":refinements,"hold_windows":hold_windows,
				"center_windows":center_windows,"failed_window":start,"failure_trace":trace,"reason":path.get("reason","invalid_trace")}
		var committed := mini(60,chunk.size())
		controls.append_array(path.controls.slice(0,committed))
		xs.append_array(path.xs.slice(1,committed+1))
		windows += 1
	return {"status":"candidate","controls":controls,"xs":xs,"windows":windows,"refinements":refinements,"hold_windows":hold_windows,
		"center_windows":center_windows,"scope":"center-biased recorded forecast candidate; unchanged actual feedback replay is still required"}

func _center_path(trace: Dictionary) -> Dictionary:
	var controls: Array = []
	var xs: Array = [trace.x0]
	for frame in trace.frames:
		var x: float = xs.back()
		var input := 0.0 if absf(x) <= 0.00000001 else -signf(x)
		var next := PathOracle._next_x(trace,frame,x,input)
		if x*next < 0.0:
			input *= absf(x/(next-x))
			next = PathOracle._next_x(trace,frame,x,input)
		controls.append(input)
		xs.append(next)
	var path := {"status":"witness","controls":controls,"xs":xs}
	if not PathOracle.validate_path(trace,path): path.status = "unverified"
	return path
var _repairing := false
var _repair_calls := 0
var _alternate_active := false
var _original_frames: Array = []
var _original_drive
var _original_hull := 100.0
var _original_x := 0.0

func _plan_trace(frames: Array, drive, hull: float = 100.0, initial_x: float = 0.0) -> Dictionary:
	if not _repairing:
		_repair_calls = 0
		_alternate_active = false
		_original_frames = frames
		_original_drive = drive
		_original_hull = hull
		_original_x = initial_x
	elif _alternate_active:
		return _plan_center_trace(frames,drive,hull,initial_x)
	var old := super._plan_trace(frames,drive,hull,initial_x)
	if old.status != "unverified": return old
	# A finite search miss is not a game impossibility. Try a different input
	# preference on the same physical trace, never relax path validation.
	var alternate := _plan_center_trace(frames,drive,hull,initial_x)
	if alternate.status == "candidate":
		_alternate_active = true
		alternate.selection_reason = "original_forecast_search_miss"
	return alternate

func _repair_from_replay(recorded: Dictionary, previous: Dictionary, hull: float = 100.0) -> Dictionary:
	_repairing = true
	var repaired := super._repair_from_replay(recorded,previous,hull)
	_repairing = false
	# Always run the original complete physical-prefix and record validation
	# first. An invalid/forged/non-contact record cannot trigger an alternate.
	if repaired.status == "invalid": return repaired
	_repair_calls += 1
	if _repair_calls == 2 and not _alternate_active and _original_frames.size() == recorded.frames.size():
		var alternate := _plan_center_trace(_original_frames,_original_drive,_original_hull,_original_x)
		if alternate.status == "candidate":
			_alternate_active = true
			alternate.selection_reason = "two_real_feedback_misses_alternate_original_forecast"
			return alternate
	return repaired
