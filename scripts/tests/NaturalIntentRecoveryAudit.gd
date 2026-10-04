extends "res://scripts/tests/NaturalAdaptiveRecoveryAudit.gd"

func _probe_source() -> Dictionary:
	var source := super._probe_source()
	if source.is_empty(): return {}
	for path in ["res://scripts/tests/NaturalAdaptiveRecoveryAudit.gd","res://scripts/tests/NaturalIntentRecoveryAudit.gd"]:
		var digest := FileAccess.get_sha256(path)
		if digest.is_empty(): return {}
		source.sha256[path] = digest
	return source

class IntentTraffic extends PathTraffic:
	func _intents() -> Dictionary:
		var result: Dictionary = {}
		for vehicle in vehicles:
			if vehicle.lane_change_enabled and vehicle.warning_started:
				var key := "%d/%d" % [vehicle.get_instance_id(),vehicle.motion_generation]
				result[key] = {"from_x":vehicle.lane*260.0-260.0,"to_x":vehicle.target_lane*260.0-260.0}
		return result
	func _tick_step(delta: float, speed: float, lane: int, frame_start: Dictionary) -> void:
		var intents := _intents()
		super._tick_step(delta,speed,lane,frame_start)
		# Preserve pre-step intent even when a change completes or is cancelled.
		# Bodies remain the original independent whole-substep geometry.
		intents.merge(_intents(),false)
		last_path_frame.lane_intents = intents

static func planning_frames(frames: Array) -> Dictionary:
	var invalid := {"status":"invalid","frames":[]}
	if frames.is_empty() or frames.size() > 7200: return invalid
	var result: Array = []
	for frame in frames:
		if frame is not Dictionary or frame.get("bodies") is not Array: return invalid
		var intents = frame.get("lane_intents",{})
		if intents is not Dictionary: return invalid
		var bodies: Array = []
		var seen: Dictionary = {}
		for original in frame.bodies:
			if original is not Dictionary: return invalid
			var body: Dictionary = original.duplicate()
			var identity = body.get("identity","")
			if intents.has(identity):
				var intent = intents[identity]
				if body.get("family","") != "npc" or intent is not Dictionary: return invalid
				for key in ["from_x","to_x"]:
					if not PathOracle._number(intent.get(key)) or float(intent[key]) not in [-260.0,0.0,260.0]: return invalid
				if absf(intent.from_x-intent.to_x) > 260.0: return invalid
				for key in ["x0","x1","half_x"]:
					if not PathOracle._number(body.get(key)): return invalid
				if body.half_x <= 0.0: return invalid
				var left: float = minf(minf(intent.from_x,intent.to_x),minf(body.x0,body.x1))
				var right: float = maxf(maxf(intent.from_x,intent.to_x),maxf(body.x0,body.x1))
				body.x0 = (left+right)*0.5
				body.x1 = body.x0
				body.half_x += (right-left)*0.5
				seen[identity] = true
			bodies.append(body)
		if seen.size() != intents.size(): return invalid
		var planned: Dictionary = frame.duplicate()
		planned.bodies = bodies
		result.append(planned)
	return {"status":"valid","frames":result}

func _plan_trace(frames: Array, drive, hull: float = 100.0, initial_x: float = 0.0) -> Dictionary:
	var prepared := planning_frames(frames)
	if prepared.status != "valid": return {"status":"invalid","controls":[],"xs":[]}
	return super._plan_trace(prepared.frames,drive,hull,initial_x)

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
	var traffic = IntentTraffic.new(sample.run_seed)
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
