extends "res://scripts/tests/ProductHardSupplyAudit.gd"
const PathTraffic = preload("res://tests/support/observed_player_path_traffic.gd")
const PathOracle = preload("res://tests/support/player_path_oracle.gd")
const Matrix = preload("res://scripts/tests/ProductTrafficMatrix.gd")

class JointMain extends MainPipelineProbe:
	func _reset_run(run_seed_override: int = -1) -> void:
		traffic = PathTraffic.new(current_run_seed,GameConfig.ROAD_LANE_COUNT,GameConfig.MIN_SPAWN_DISTANCE,GameConfig.MIN_TRAFFIC_GAP)
		traffic.configure_track(current_track)
		traffic.set_viewport_height(get_viewport_rect().size.y)
		# Let the real reset apply seed/profile in the original order: applying
		# a profile after reset draws another construction cooldown.
		super._reset_run(run_seed_override)

func _pipeline_script() -> Script:
	return JointMain

func _run() -> void:
	if OS.get_cmdline_user_args() == PackedStringArray(["--selfcheck"]):
		quit(0 if await _selfcheck() else 1)
	elif not OS.get_cmdline_user_args().is_empty() and not select_cases(OS.get_cmdline_user_args()).is_empty():
		await super._run()
	else:
		quit(2)

func _selfcheck() -> bool:
	var fixture_frame := {"dt":DT,"speed":800.0,"status":"valid","bodies":[]}
	_check(_path_outcome(fixture_frame,0.0,0.0) == "clear","unobstructed real frame is clear")
	fixture_frame.bodies = [{"x0":0.0,"x1":0.0,"y0":592.0,"y1":592.0,"half_x":25.0,"half_y":42.0}]
	_check(_path_outcome(fixture_frame,0.0,0.0) == "contact","actual player body contact cannot count as a clear path")
	fixture_frame.status = "invalid"
	_check(_path_outcome(fixture_frame,0.0,0.0) == "invalid","invalid independent frame cannot count as a clear path")
	fixture_frame.status = "valid"
	_check(_path_outcome(fixture_frame,0.0,INF) == "invalid","non-finite actual position is invalid")
	root.size = Vector2i(1280,720)
	var observed = MainScene.instantiate()
	observed.set_script(JointMain)
	root.add_child(observed)
	observed.set_process(false)
	var plain = MainScene.instantiate()
	root.add_child(plain)
	plain.set_process(false)
	var config := {"track_id":"neon_coast","vehicle_id":"pulse_gt","difficulty_index":2,"run_seed":611}
	Launcher.configure_main(observed,config)
	Launcher.configure_main(plain,config)
	_check(observed.traffic is PathTraffic,"actual Main installs independent path traffic before driving")
	_check(not observed.persistence_enabled and not plain.persistence_enabled and current_scene != observed and current_scene != plain,"both transparent comparison instances stay off formal save path")
	Input.action_press("accelerate")
	var mismatch_logged := false
	for frame in 260:
		observed._process(DT)
		plain._process(DT)
		var first := _traffic_snapshot(observed.traffic)
		var second := _traffic_snapshot(plain.traffic)
		for body in first+second: body.erase("identity")
		if not mismatch_logged and (first != second or observed.traffic._random.state != plain.traffic._random.state or observed.traffic.lane_events._random.state != plain.traffic.lane_events._random.state):
			mismatch_logged = true
			print("MAIN_OBSERVER_FIRST_DIFFERENCE ",JSON.stringify({"frame":frame,"observed":first,"plain":second,
				"observed_rng":observed.traffic._random.state,"plain_rng":plain.traffic._random.state,
				"observed_event_rng":observed.traffic.lane_events._random.state,"plain_event_rng":plain.traffic.lane_events._random.state,
				"observed_next_event":observed.traffic.lane_events._cooldown_remaining,"plain_next_event":plain.traffic.lane_events._cooldown_remaining}))
		_check(first == second and observed.traffic._random.state == plain.traffic._random.state and observed.traffic.lane_events._random.state == plain.traffic.lane_events._random.state,"Main observer preserves every NPC state and random stream")
		_check(observed.drive.speed == plain.drive.speed and observed.drive.lateral_position == plain.drive.lateral_position and observed.run.fuel == plain.run.fuel and observed.run.distance == plain.run.distance and observed.run.phase == plain.run.phase,"Main observer preserves real driving and resources")
	_release_input()
	var playbacks: Array[WeakRef] = AudioTeardown.capture(observed)
	playbacks.append_array(AudioTeardown.capture(plain))
	observed.audio_director.shutdown()
	plain.audio_director.shutdown()
	observed.free()
	plain.free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self,playbacks),"both comparison instances retire playback ownership")
	print("MAIN_JOINT_SELFCHECK_COMPLETE frames=260 failures=%d" % failures.size())
	for failure in failures: print("MAIN_JOINT_SELFCHECK_FAIL "+failure)
	return failures.is_empty()

static func _path_outcome(frame: Dictionary,before_x: float,after_x: float) -> String:
	var trace := {"x0":before_x,"y":592.0,"road_half":390.0,"half_x":30.0,"half_y":30.0,
		"steering_speed":1.0,"max_speed":1.0,"hull":100.0,"frames":[frame]}
	if not PathOracle._valid_trace(trace) or not is_finite(after_x) or absf(after_x) > 360.0: return "invalid"
	return "clear" if PathOracle._clear(trace,frame,before_x,after_x) else "contact"

func _source_metadata() -> Dictionary:
	var result := super._source_metadata()
	result.main_joint_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var paths := Matrix.SOURCE_FILES.duplicate()
	paths.append_array(["res://tests/support/player_path_oracle.gd","res://tests/support/observed_player_path_traffic.gd"])
	result.joint_sha256 = {}
	for path in paths: result.joint_sha256[path] = FileAccess.get_sha256(path)
	return result

func _apply_directed_input(main,stats: Dictionary) -> void:
	super._apply_directed_input(main,stats)
	if not stats.has("joint_path"):
		stats.joint_path = {"world_frames":0,"clear_frames":0,"contact_frames":0,"invalid_frames":0,"terminal_bypass_frames":0,
			"first_contact":{},"independent_issue_counts":{},"scope":"actual Main trajectory conservative envelopes; contacts describe this input pilot, not proof of unavoidable collision"}
	stats.pre_joint_x = main.drive.lateral_position
	stats.pre_joint_steps = main.traffic.motion_steps

func _validate_resources(main,before: Dictionary,contacts: Dictionary,stats: Dictionary) -> void:
	super._validate_resources(main,before,contacts,stats)
	var observed_steps: int = main.traffic.motion_steps-stats.pre_joint_steps
	_check(observed_steps in [0,1],"real fixed-step Main path observes every traffic substep")
	if observed_steps == 0:
		_check(main.run.phase != Run.Phase.RUNNING,"no traffic substep only occurs at real resource terminal bypass")
		stats.joint_path.terminal_bypass_frames += 1
		stats.erase("pre_joint_x")
		stats.erase("pre_joint_steps")
		return
	stats.joint_path.world_frames += 1
	var frame: Dictionary = main.traffic.last_path_frame
	var outcome := _path_outcome(frame,stats.pre_joint_x,main.drive.lateral_position)
	stats.joint_path[outcome+"_frames"] += 1
	_check(outcome != "invalid","actual Main traffic source and player coordinates are valid")
	if outcome == "contact" and stats.joint_path.first_contact.is_empty():
		stats.joint_path.first_contact = {"frame":frame_index,"x_before":stats.pre_joint_x,"x_after":main.drive.lateral_position,
			"speed":frame.speed,"hull_before":before.hull,"hull_after":main.integrity.current,"collisions":main.run.collisions,"bodies":frame.bodies}
	var groups := {"npc":main.traffic.issue_counts,"core":main.traffic.core_issue_counts,"motion":main.traffic.motion_issue_counts,"change":main.traffic.change_issue_counts}
	stats.joint_path.independent_issue_counts = groups.duplicate(true)
	var issue_total := 0
	for counts in groups.values():
		for count in counts.values(): issue_total += count
	_check(issue_total == 0,"actual Main NPC/core/motion/warning independent traffic gates remain clean")
	stats.erase("pre_joint_x")
	stats.erase("pre_joint_steps")
