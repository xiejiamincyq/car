extends "res://scripts/tests/ProductTrafficMatrix.gd"
const PathOracle = preload("res://tests/support/player_path_oracle.gd")
const PathTraffic = preload("res://tests/support/observed_player_path_traffic.gd")
const Hull = preload("res://scripts/vehicle_integrity.gd")

static func select_route_cases(args: PackedStringArray) -> Array[Dictionary]:
	if args.is_empty(): return []
	return select_cases(args)

class SteeredDrive extends Drive:
	var control := 0.0
	var hull = Hull.new()
	func step(delta: float, accelerate: float, brake: float, _steer: float = 0.0, speed_bonus: float = 0.0,
		acceleration_bonus: float = 0.0, _speed_multiplier: float = 1.0, _steer_multiplier: float = 1.0) -> void:
		super.step(delta,accelerate,brake,control,speed_bonus,acceleration_bonus,hull.max_speed_multiplier(),hull.steering_multiplier())

func _init() -> void:
	call_deferred("_entry")

func _entry() -> void:
	var args := OS.get_cmdline_user_args()
	if args == PackedStringArray(["--selfcheck"]):
		quit(0 if _selfcheck() else 1)
		return
	var hull := 100.0
	if args.size() == 3 and args[0] == "--hull30":
		hull = 30.0
		args = args.slice(1)
	var cases := select_route_cases(args)
	if cases.is_empty():
		quit(2)
		return
	var folder := "res://tmp/product-natural-path-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	if DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) != OK:
		quit(2)
		return
	var source := _probe_source()
	if source.is_empty():
		quit(2)
		return
	var rows: Array[Dictionary] = []
	var unresolved := 0
	print("JOINT_PATH_CONFIG ",JSON.stringify({"planned":cases.size(),"full_planned":1080,"arguments":Array(args),"steps":7200,"source":source,"initial_constant_hull_fixture":hull,
		"scope":"natural traffic model, original longitudinal curves and constant controller fuel; Main resource termination/human experience are separate"}))
	for sample in cases:
		var started := Time.get_ticks_usec()
		var forecast := _collect_case(sample,7200,[],hull)
		var trajectory := forecast
		var candidate: Dictionary = {}
		var replay: Dictionary = {}
		var attempts: Array = []
		var status := "unverified"
		# Bounded offline refinement, not an online autopilot. A new forecast
		# never counts as success: every candidate needs its own actual replay.
		for attempt in 4:
			candidate = _plan_trace(trajectory.frames,trajectory.drive,hull,trajectory.xs[0]) if attempt == 0 else _repair_from_replay(trajectory,candidate,hull)
			status = candidate.status
			if candidate.status != "candidate": break
			replay = _collect_case(sample,7200,candidate.controls,hull)
			status = "joint_replay_witness" if _validate_joint(replay,candidate,hull) else "unverified_replay"
			if replay.status == "invalid": status = "invalid_replay"
			var saved_replay := replay.duplicate()
			saved_replay.erase("drive")
			attempts.append({"candidate":candidate,"replay":saved_replay,"status":status})
			print("JOINT_PATH_ATTEMPT ",JSON.stringify({"case_id":sample.case_id,"attempt":attempt+1,"status":status}))
			if status in ["joint_replay_witness","invalid_replay"]: break
			trajectory = replay
		if status != "joint_replay_witness": unresolved += 1
		var row := {"case_id":sample.case_id,"definition":sample,"status":status,"hull_fixture":hull,
			"planned_steps":7200,"forecast_steps":forecast.frames.size(),"replay_steps":replay.get("frames",[]).size(),
			"windows":candidate.get("windows",0),"refinements":candidate.get("refinements",0),"failed_window":candidate.get("failed_window",-1),"attempts":attempts.size(),
			"forecast_births":forecast.births,"forecast_changes":forecast.changes,"forecast_core_births":forecast.core_births,
			"forecast_independent_issues":forecast.independent_issues,"replay_independent_issues":replay.get("independent_issues",-1),
			"hold_windows":candidate.get("hold_windows",0),"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0}
		forecast.erase("drive")
		replay.erase("drive")
		var file := FileAccess.open(folder+"/%d.json" % rows.size(),FileAccess.WRITE)
		if file == null:
			quit(2)
			return
		file.store_string(JSON.stringify({"source":source,"row":row,"forecast":forecast,"candidate":candidate,"replay":replay,"attempts":attempts}))
		var written := file.get_error() == OK
		file.close()
		if not written:
			quit(2)
			return
		rows.append(row)
		print("JOINT_PATH_ROW ",JSON.stringify(row))
	var stable := source == _probe_source()
	var summary := FileAccess.open(folder+"/summary.json",FileAccess.WRITE)
	if summary == null:
		quit(2)
		return
	summary.store_string(JSON.stringify({"source":source,"arguments":Array(args),"planned":cases.size(),"completed":rows.size(),"unresolved":unresolved,
		"source_stable":stable,"initial_constant_hull_fixture":hull,"rows":rows}))
	var summary_written := summary.get_error() == OK
	summary.close()
	if not summary_written:
		quit(2)
		return
	print("JOINT_PATH_COMPLETE ",JSON.stringify({"planned":cases.size(),"completed":rows.size(),"unresolved":unresolved,"source_stable":stable,"folder":folder}))
	quit(0 if unresolved == 0 and stable else 1)

func _probe_source() -> Dictionary:
	var source := _matrix_source()
	if source.is_empty(): return {}
	for path in ["res://tests/support/player_path_oracle.gd","res://tests/support/observed_player_path_traffic.gd","res://scripts/vehicle_integrity.gd",
		"res://scripts/tests/ProductTrafficMatrix.gd","res://scripts/tests/ProductNaturalPathAudit.gd"]:
		var digest := FileAccess.get_sha256(path)
		if digest.is_empty(): return {}
		source.sha256[path] = digest
	return source

func _plan_trace(frames: Array, drive, hull: float = 100.0, initial_x: float = 0.0) -> Dictionary:
	if frames.is_empty() or frames.size() > 7200: return {"status":"invalid","controls":[],"xs":[]}
	var controls: Array = []
	var xs: Array = [initial_x]
	var windows := 0
	var refinements := 0
	var hold_windows := 0
	# Inspect two seconds, commit at most one: the next boundary is already
	# inside the previous search, rather than a blind first-frame surprise.
	for start in range(0,frames.size(),60):
		var chunk := frames.slice(start,mini(start+120,frames.size()))
		var trace := {"x0":xs.back(),"y":592.0,"road_half":drive.road_half_width,"half_x":drive.player_half_width,"half_y":30.0,
			"steering_speed":drive.steering_speed,"max_speed":drive.max_speed,"hull":hull,"frames":chunk}
		# The default search visits zero steering first. If its entire lookahead
		# is independently valid, avoid enumerating alternatives to that same path.
		var hold_controls: Array = []
		var hold_xs: Array = [trace.x0]
		for _index in chunk.size():
			hold_controls.append(0.0)
			hold_xs.append(trace.x0)
		var path: Dictionary = {"status":"witness","controls":hold_controls,"xs":hold_xs}
		if PathOracle.validate_path(trace,path):
			hold_windows += 1
		else:
			path = PathOracle.find_path(trace)
		if path.status == "unverified":
			refinements += 1
			path = PathOracle.find_path(trace,[0.0,-1.0,-0.5,0.5,1.0])
		if path.status != "witness":
			return {"status":path.status,"controls":controls,"xs":xs,"windows":windows,"refinements":refinements,"hold_windows":hold_windows,
				"failed_window":start,"failure_trace":trace,"reason":path.get("reason","invalid_trace")}
		var committed := mini(60,chunk.size())
		controls.append_array(path.controls.slice(0,committed))
		xs.append_array(path.xs.slice(1,committed+1))
		windows += 1
	return {"status":"candidate","controls":controls,"xs":xs,"windows":windows,"refinements":refinements,"hold_windows":hold_windows,
		"scope":"recorded traffic forecast candidate; own actual feedback replay still required"}

func _selfcheck() -> bool:
	var failures: Array[String] = []
	if not select_route_cases([]).is_empty(): failures.append("empty request cannot accidentally run the full long matrix")
	if select_route_cases(["--pilot"]).size() != 5: failures.append("pilot contains exactly five canonical cases")
	var all_cases: Dictionary = {}
	for shard in 18:
		var selected := select_route_cases(["--shard",str(shard)])
		if selected.size() != 60: failures.append("each of eighteen matrix partitions has sixty cases")
		for sample in selected:
			if all_cases.has(sample.case_id): failures.append("shards must not duplicate a case")
			all_cases[sample.case_id] = true
	if all_cases.size() != 1080: failures.append("all route partitions retain the full 1080 denominator")
	for args in [["--shard","-1"],["--shard","18"],["--shard","oops"],["--case","missing"],["--pilot","extra"]]:
		if not select_route_cases(PackedStringArray(args)).is_empty(): failures.append("invalid request rejected")
	var drive = SteeredDrive.new(800.0,800.0,220.0,420.0,500.0,390.0,30.0)
	drive.control = 0.5
	drive.hull.current = 30.0
	drive.step(STEP,1.0,0.0)
	var reference = Drive.new(800.0,800.0,220.0,420.0,500.0,390.0,30.0)
	reference.step(STEP,1.0,0.0,0.5,0.0,0.0,0.78,0.68)
	if drive.speed != reference.speed or drive.lateral_position != reference.lateral_position: failures.append("actual steering/hull input bridge")
	var frames: Array = []
	for index in 240: frames.append({"dt":STEP,"speed":800.0,"bodies":[],"status":"valid"})
	var plan := _plan_trace(frames,drive)
	if plan.status != "candidate" or plan.controls.size() != 240 or plan.xs.size() != 241: failures.append("whole candidate carries contiguous controls/coordinates across two windows")
	if plan.get("hold_windows",0) != 4: failures.append("four proven straight windows skip exhaustive search without changing route validation")
	frames[120].status = "invalid"
	if _plan_trace(frames,drive).status != "invalid": failures.append("invalid second window is not silently dropped")
	var boundary_hazard := frames.duplicate(true)
	boundary_hazard[120].status = "valid"
	boundary_hazard[120].bodies = [{"x0":0.0,"x1":0.0,"y0":592.0,"y1":592.0,"half_x":25.0,"half_y":42.0}]
	var hazard_plan := _plan_trace(boundary_hazard,drive)
	if hazard_plan.status != "candidate" or hazard_plan.get("hold_windows",4) >= 4: failures.append("blocked straight lookahead falls back to advance steering search")
	var sample: Dictionary = build_cases()[0]
	var recorded := _collect_case(sample,2)
	if recorded.get("frames",[]).size() != 2 or recorded.get("xs",[]).size() != 3: failures.append("actual natural collector records all requested steps and positions")
	if _collect_case(sample,2,[0.0]).status != "invalid": failures.append("truncated steering sequence must not default to zero")
	var empty_record := {"status":"valid","frames":[],"xs":[0.0],"drive":drive}
	if _validate_joint(empty_record,{"status":"candidate","controls":[],"xs":[0.0]}): failures.append("empty replay cannot be a route witness")
	if recorded.status == "valid":
		var candidate := _plan_trace(recorded.frames,recorded.drive)
		if not _validate_joint(recorded,candidate): failures.append("a real unobstructed input replay is accepted")
		candidate.xs[1] += 1.0
		if _validate_joint(recorded,candidate): failures.append("forged coordinate cannot pass actual drive replay")
		recorded.drive.lateral_position = 60.0
		var revised := _plan_trace(recorded.frames,recorded.drive)
		if revised.xs[0] != recorded.xs[0]: failures.append("replanning recorded traffic starts from actual initial position, not drive final position")
	var safe_prefix: Array = []
	var prefix_xs: Array = [0.0]
	var prefix_drive = Drive.new(800.0,800.0,220.0,420.0,500.0,390.0,30.0)
	for index in 240:
		var input := 1.0 if index == 0 else 0.0
		prefix_drive.step(STEP,1.0,0.0,input)
		safe_prefix.append(input)
		prefix_xs.append(prefix_drive.lateral_position)
	var contact_frames := frames.duplicate(true)
	contact_frames[120].status = "valid"
	contact_frames[180].bodies = [{"x0":0.0,"x1":0.0,"y0":592.0,"y1":592.0,"half_x":25.0,"half_y":42.0}]
	var old_plan := {"status":"candidate","controls":safe_prefix,"xs":prefix_xs}
	var actual := {"status":"valid","frames":contact_frames,"drive":prefix_drive,"xs":prefix_xs}
	var repaired := _repair_from_replay(actual,old_plan)
	if repaired.status != "candidate" or repaired.controls[0] != old_plan.controls[0] or repaired.xs.slice(0,61) != old_plan.xs.slice(0,61):
		failures.append("suffix repair preserves verified first sixty actual input steps and positions")
	if repaired.status == "candidate":
		for index in contact_frames.size():
			if not PathOracle._clear({"half_x":30.0,"half_y":30.0,"y":592.0},contact_frames[index],repaired.xs[index],repaired.xs[index+1]):
				failures.append("repaired prefix and suffix must both remain clear on recorded bodies")
				break
	var truncated := old_plan.duplicate()
	truncated.controls = old_plan.controls.slice(0,239)
	if _repair_from_replay(actual,truncated).status != "invalid": failures.append("incomplete prior input must not be a repair prefix")
	for input in [2.0,INF,0.0]:
		var forged := old_plan.duplicate(true)
		forged.controls[0] = input
		if _repair_from_replay(actual,forged).status != "invalid": failures.append("forged prefix control cannot reuse unrelated actual coordinates")
	print("JOINT_PATH_SELFCHECK_COMPLETE failures=%d" % failures.size())
	for failure in failures: print("JOINT_PATH_SELFCHECK_FAIL "+failure)
	return failures.is_empty()

func _repair_from_replay(recorded: Dictionary,previous: Dictionary,hull: float = 100.0) -> Dictionary:
	var invalid := {"status":"invalid","controls":[],"xs":[]}
	if recorded.status != "valid" or previous.status != "candidate": return invalid
	if recorded.frames.is_empty() or recorded.frames.size() > 7200 or recorded.xs.size() != recorded.frames.size()+1: return invalid
	if previous.controls.size() != recorded.frames.size() or previous.xs.size() != recorded.xs.size(): return invalid
	for index in previous.xs.size():
		if not is_finite(previous.xs[index]) or absf(previous.xs[index]-recorded.xs[index]) > 0.0000001: return invalid
	var physical := {"road_half":recorded.drive.road_half_width,"half_x":recorded.drive.player_half_width,
		"steering_speed":recorded.drive.steering_speed,"max_speed":recorded.drive.max_speed,"hull":hull}
	for index in previous.controls.size():
		var input = previous.controls[index]
		if not PathOracle._number(input) or absf(input) > 1.0: return invalid
		var next := PathOracle._next_x(physical,recorded.frames[index],previous.xs[index],input)
		if absf(next-previous.xs[index+1]) > 0.0000001: return invalid
	var contact := -1
	for index in recorded.frames.size():
		if not PathOracle._clear({"half_x":30.0,"half_y":30.0,"y":592.0},recorded.frames[index],previous.xs[index],previous.xs[index+1]):
			contact = index
			break
	if contact == -1: return invalid # A non-contact validation error is not a planning problem.
	var start := maxi(0,contact-120)
	var suffix := _plan_trace(recorded.frames.slice(start),recorded.drive,hull,recorded.xs[start])
	if suffix.status != "candidate":
		suffix.failed_window = start+int(suffix.get("failed_window",0))
		return suffix
	var controls: Array = previous.controls.slice(0,start)
	controls.append_array(suffix.controls)
	var xs: Array = previous.xs.slice(0,start+1)
	xs.append_array(suffix.xs.slice(1))
	suffix.controls = controls
	suffix.xs = xs
	suffix.preserved_prefix_steps = start
	suffix.repair_from_contact = contact
	return suffix

func _collect_case(sample: Dictionary, steps: int, controls: Array = [], hull: float = 100.0) -> Dictionary:
	var invalid := {"status":"invalid","frames":[],"xs":[]}
	if steps < 1 or steps > 7200 or not is_finite(hull) or hull < 20.0 or hull > 100.0: return invalid
	if not controls.is_empty() and controls.size() != steps: return invalid
	for control in controls:
		if typeof(control) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(control) or absf(control) > 1.0: return invalid
	var setup := setup_case(sample)
	if setup.is_empty(): return invalid
	var original = setup.drive
	var drive = SteeredDrive.new(original.start_speed,original.max_speed,original.acceleration,original.braking,
		original.steering_speed,original.road_half_width,original.player_half_width)
	drive.hull.current = hull
	var traffic = PathTraffic.new(sample.run_seed)
	traffic.configure_track(Tracks.get_by_id(StringName(sample.track_id)))
	traffic.configure_difficulty(Difficulty.for_index(sample.difficulty_index))
	traffic.set_viewport_height(720.0)
	var frames: Array = []
	var xs: Array = [drive.lateral_position]
	var stats := {"overdrive_activations":0,"brake_frames":0}
	var valid := true
	for step in steps:
		drive.control = 0.0 if controls.is_empty() else controls[step]
		_apply_input(drive,setup.overdrive,sample.trajectory,step,stats)
		traffic.set_difficulty_stage(mini(3,int(step*STEP/30.0)))
		traffic.tick(STEP,drive.speed,clampi(int(floor((drive.lateral_position+390.0)/260.0)),0,2))
		frames.append(traffic.last_path_frame.duplicate(true))
		xs.append(drive.lateral_position)
		valid = valid and traffic.last_path_frame.status == "valid"
	var groups := {"npc":traffic.issue_counts,"core":traffic.core_issue_counts,"motion":traffic.motion_issue_counts,"change":traffic.change_issue_counts}
	var issues := 0
	for counts in groups.values():
		for count in counts.values(): issues += count
	return {"status":"valid" if valid and issues == 0 else "invalid","frames":frames,"xs":xs,"drive":drive,
		"input_observed":stats,"independent_issues":issues,"issue_counts":groups,"births":traffic.birth_count,
		"core_births":traffic.core_birth_count,"warnings":traffic.warnings_observed,"changes":traffic.starts_observed}

func _validate_joint(recorded: Dictionary, candidate: Dictionary, hull: float = 100.0) -> bool:
	if recorded.status != "valid" or candidate.status != "candidate": return false
	if recorded.frames.is_empty() or recorded.frames.size() > 7200 or recorded.xs.size() != recorded.frames.size()+1: return false
	if candidate.controls.size() != recorded.frames.size() or candidate.xs.size() != recorded.xs.size(): return false
	for index in candidate.xs.size():
		if not is_finite(candidate.xs[index]) or absf(candidate.xs[index]-recorded.xs[index]) > 0.0000001: return false
	var drive = recorded.drive
	for start in range(0,recorded.frames.size(),120):
		var end := mini(start+120,recorded.frames.size())
		var trace := {"x0":candidate.xs[start],"y":592.0,"road_half":drive.road_half_width,"half_x":drive.player_half_width,"half_y":30.0,
			"steering_speed":drive.steering_speed,"max_speed":drive.max_speed,"hull":hull,"frames":recorded.frames.slice(start,end)}
		if not PathOracle.validate_path(trace,{"xs":candidate.xs.slice(start,end+1),"controls":candidate.controls.slice(start,end)}): return false
	return true
