extends "res://scripts/tests/ProductTrafficBaseline.gd"
const Cars = preload("res://scripts/catalog/vehicle_catalog.gd")
const Recorder = preload("res://tests/support/observed_change_traffic.gd")
const SHARDS := 18
const SOURCE_FILES := [
	"res://scripts/traffic_director.gd","res://scripts/traffic_vehicle.gd","res://scripts/traffic_safety_policy.gd",
	"res://scripts/lane_event_director.gd","res://scripts/track_geometry.gd","res://scripts/game_config.gd",
	"res://scripts/drive_controller.gd","res://scripts/overdrive_controller.gd","res://scripts/difficulty_profile.gd",
	"res://scripts/catalog/track_catalog.gd","res://scripts/catalog/vehicle_catalog.gd","res://scripts/tests/ProductTrafficBaseline.gd",
	"res://tests/support/traffic_audit_geometry.gd","res://tests/support/observed_traffic.gd","res://tests/support/observed_lane_events.gd",
	"res://tests/support/traffic_core_audit.gd","res://tests/support/observed_core_traffic.gd","res://tests/support/traffic_motion_audit.gd",
	"res://tests/support/observed_motion_traffic.gd","res://tests/support/observed_change_traffic.gd",
]

class MatrixTraffic extends Recorder:
	var scheduled_opportunities := 0
	var capacity_skips := 0
	var candidate_attempts := 0
	func _spawn_next(speed: float, lane: int) -> void:
		scheduled_opportunities += 1
		if vehicles.size() >= target_active_vehicles: capacity_skips += 1
		else: candidate_attempts += 1
		super._spawn_next(speed,lane)

func _init() -> void:
	call_deferred("_run_matrix")

func _run_matrix() -> void:
	var arguments := OS.get_cmdline_user_args()
	var cases := select_cases(arguments)
	var source := _matrix_source()
	if cases.is_empty() or source.is_empty():
		push_error("PRODUCT_TRAFFIC_INVALID_REQUEST requires exact args and source metadata")
		quit(2)
		return
	var folder := "res://tmp/product-traffic-matrix-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	if DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("PRODUCT_TRAFFIC_EVIDENCE_FOLDER_FAILED")
		quit(2)
		return
	var rows: Array[Dictionary] = []
	var failed := 0
	var started := Time.get_ticks_usec()
	print("PRODUCT_TRAFFIC_CONFIG ",JSON.stringify({"planned":cases.size(),"full_planned":1080,"arguments":Array(arguments),"source":source,
		"reachable_status":"not_audited","scope":"traffic motion/geometry/lifecycle gate only; continuous reachability and resource Main are separate required gates"}))
	for sample in cases:
		var begin := Time.get_ticks_usec()
		var row := sample_case(sample)
		row.wall_seconds = (Time.get_ticks_usec()-begin)/1000000.0
		rows.append(row)
		if row.get("independent_issues",-1) != 0: failed += 1
		print("PRODUCT_TRAFFIC_ROW ",JSON.stringify(row))
	var stable: bool = source == _matrix_source()
	var summary := {"source":source,"arguments":Array(arguments),"planned":cases.size(),"completed":rows.size(),"failed_cases":failed,
		"source_stable":stable,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"rows":rows,"reachable_status":"not_audited"}
	var file := FileAccess.open(folder+"/summary.json",FileAccess.WRITE)
	if file == null:
		push_error("PRODUCT_TRAFFIC_EVIDENCE_WRITE_FAILED")
		quit(2)
		return
	file.store_string(JSON.stringify(summary,"\t"))
	var written: bool = file.get_error() == OK
	file.close()
	if not written:
		push_error("PRODUCT_TRAFFIC_EVIDENCE_WRITE_FAILED")
		quit(2)
		return
	print("PRODUCT_TRAFFIC_COMPLETE ",JSON.stringify({"planned":cases.size(),"completed":rows.size(),"failed_cases":failed,"source_stable":stable,
		"wall_seconds":summary.wall_seconds,"summary_path":folder+"/summary.json","reachable_status":"not_audited"}))
	quit(0 if failed == 0 and stable else 1)

func _matrix_source() -> Dictionary:
	var output: Array = []
	if OS.execute("git",["-C",ProjectSettings.globalize_path("res://"),"rev-parse","HEAD"],output) != 0 or output.size() != 1: return {}
	var hashes: Dictionary = {}
	var files := SOURCE_FILES.duplicate()
	files.append(get_script().resource_path)
	for path in files:
		var digest := FileAccess.get_sha256(path)
		if digest.is_empty(): return {}
		hashes[path] = digest
	return {"head":String(output[0]).strip_edges(),"sha256":hashes,"engine":Engine.get_version_info().string}

static func build_cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for track in Tracks.all():
		for car in Cars.all():
			for difficulty in 3:
				for seed in SEEDS:
					for trajectory in TRAJECTORIES:
						result.append({"track_id":String(track.id),"vehicle_id":String(car.id),"difficulty_index":difficulty,
							"run_seed":seed,"trajectory":trajectory,"case_id":"%s/%s/difficulty%d/%s/seed%d" % [track.id,car.id,difficulty,trajectory,seed]})
	return result

static func select_cases(arguments: PackedStringArray) -> Array[Dictionary]:
	var cases := build_cases()
	if arguments.is_empty(): return cases
	if arguments == PackedStringArray(["--pilot"]):
		return cases.filter(func(sample): return _is_pilot(sample))
	if arguments.size() == 2 and arguments[0] == "--case":
		return cases.filter(func(sample): return sample.case_id == arguments[1])
	if arguments.size() != 2 or arguments[0] != "--shard" or not arguments[1].is_valid_int(): return []
	var shard := arguments[1].to_int()
	if shard < 0 or shard >= SHARDS: return []
	var selected: Array[Dictionary] = []
	for index in cases.size():
		if index%SHARDS == shard: selected.append(cases[index])
	return selected

static func _is_pilot(sample: Dictionary) -> bool:
	return (
		(sample.track_id == "neon_coast" and sample.vehicle_id == "pulse_gt" and sample.difficulty_index == 1 and sample.run_seed == 611)
		or (sample.track_id == "storm_ridge" and sample.vehicle_id == "aurora_x" and sample.difficulty_index == 2 and sample.run_seed == 616 and sample.trajectory == "overdrive_brake")
		or (sample.track_id == "sunrise_express" and sample.vehicle_id == "comet_rs" and sample.difficulty_index == 2 and sample.run_seed == 618 and sample.trajectory == "brake_repass")
	)

static func setup_case(sample: Dictionary) -> Dictionary:
	for field in ["track_id","vehicle_id","difficulty_index","run_seed","trajectory","case_id"]:
		if not sample.has(field): return {}
	if typeof(sample.difficulty_index) != TYPE_INT or sample.difficulty_index < 0 or sample.difficulty_index >= 3 or not SEEDS.has(sample.run_seed) or not TRAJECTORIES.has(sample.trajectory): return {}
	if sample.case_id != "%s/%s/difficulty%d/%s/seed%d" % [sample.track_id,sample.vehicle_id,sample.difficulty_index,sample.trajectory,sample.run_seed]: return {}
	var track := Tracks.get_by_id(StringName(sample.track_id))
	var car := Cars.get_by_id(StringName(sample.vehicle_id))
	if track.is_empty() or car.is_empty(): return {}
	var drive := Drive.new(minf(Config.START_SPEED,car.max_speed),car.max_speed,car.acceleration,car.braking,
		car.steering_speed*track.steering_multiplier,Config.ROAD_HALF_WIDTH,30.0)
	var traffic := MatrixTraffic.new(sample.run_seed)
	traffic.configure_track(track)
	traffic.configure_difficulty(Difficulty.for_index(sample.difficulty_index))
	traffic.set_viewport_height(720.0)
	return {"drive":drive,"traffic":traffic,"overdrive":Overdrive.new()}

func sample_case(sample: Dictionary, budget: float = 120.0) -> Dictionary:
	if not is_finite(budget) or budget < STEP or budget > SAMPLE_SECONDS: return {"error":"invalid_budget"}
	var setup := setup_case(sample)
	if setup.is_empty(): return {"error":"invalid_case"}
	var traffic = setup.traffic
	var drive = setup.drive
	var overdrive = setup.overdrive
	var stats := {"overdrive_activations":0,"brake_frames":0}
	var visible_car_seconds := 0.0
	var visible_fast_seconds := 0.0
	var empty_seconds := 0.0
	var empty_run := 0.0
	var longest_empty := 0.0
	var empty_after_warmup := 0.0
	var longest_after_warmup := 0.0
	var legacy_wall_frames := 0
	var legacy_no_escape_seconds := 0.0
	var legacy_blocked_run := 0.0
	var legacy_longest_blocked := 0.0
	var frames := roundi(budget/STEP)
	var runtime := {"maximum_speed":drive.max_speed,"acceleration":drive.acceleration,"braking":drive.braking,
		"steering":drive.steering_speed,"player_half_width":drive.player_half_width,"road_half_width":drive.road_half_width,
		"track_pattern":String(traffic.track_pattern),"traffic_interval_multiplier":traffic.spawn_interval_multiplier,
		"track_spawn_multiplier":traffic.track_spawn_interval_multiplier,"event_interval_multiplier":traffic.lane_events.interval_multiplier,
		"random_change_probability":traffic.random_lane_change_probability,"double_closure_probability":traffic.lane_events.double_lane_probability}
	for step in frames:
		_apply_input(drive,overdrive,sample.trajectory,step,stats)
		traffic.set_difficulty_stage(mini(3,int(step*STEP/30.0)))
		traffic.tick(STEP,drive.speed,1)
		var visible := 0
		for vehicle in traffic.vehicles:
			if vehicle.y+vehicle.half_length >= 0.0 and vehicle.y-vehicle.half_length <= 720.0:
				visible += 1
				if vehicle.kind == 2: visible_fast_seconds += STEP
		visible_car_seconds += visible*STEP
		empty_seconds += STEP if visible == 0 else 0.0
		empty_run = empty_run+STEP if visible == 0 else 0.0
		longest_empty = maxf(longest_empty,empty_run)
		if (step+1)*STEP > WARMUP_SECONDS:
			empty_after_warmup = empty_after_warmup+STEP if visible == 0 else 0.0
			longest_after_warmup = maxf(longest_after_warmup,empty_after_warmup)
		# These existing production lane-set indicators remain congestion
		# proxies, never the independent continuous reachable-player proof.
		legacy_wall_frames += 1 if traffic.has_full_lane_wall() else 0
		var blocked: bool = traffic.reachable_player_lanes(1,592.0,traffic.braking_reaction_clearance(drive.speed)).is_empty()
		legacy_no_escape_seconds += STEP if blocked else 0.0
		legacy_blocked_run = legacy_blocked_run+STEP if blocked else 0.0
		legacy_longest_blocked = maxf(legacy_longest_blocked,legacy_blocked_run)
	var issues: Dictionary = {"npc":traffic.issue_counts.duplicate(),"core":traffic.core_issue_counts.duplicate(),
		"motion":traffic.motion_issue_counts.duplicate(),"change":traffic.change_issue_counts.duplicate()}
	var independent_issues := 0
	for group in issues.values():
		for count in group.values(): independent_issues += int(count)
	return {"case_id":sample.case_id,"definition":sample.duplicate(),"runtime_config":runtime,"frames":frames,
		"internal_steps":traffic.motion_steps,"frame_checks":traffic.frame_checks,"maximum_substep":traffic.maximum_step,
		"simulated_seconds":frames*STEP,"final_speed":drive.speed,"visible_car_seconds":visible_car_seconds,
		"average_visible_cars":visible_car_seconds/(frames*STEP),"visible_fast_seconds":visible_fast_seconds,
		"empty_seconds":empty_seconds,"longest_empty_seconds":longest_empty,"longest_empty_after_warmup_seconds":longest_after_warmup,
		"scheduled_opportunities":traffic.scheduled_opportunities,"capacity_skips":traffic.capacity_skips,
		"candidate_attempts":traffic.candidate_attempts,"accepted":traffic.birth_count,"rejected":traffic.candidate_attempts-traffic.birth_count,
		"npc_retired":traffic.retirement_count,"core_births":traffic.core_birth_count,"core_retired":traffic.core_retirement_count,
		"aborted_core_births":traffic.aborted_core_birth_count,
		"warnings":traffic.warnings_observed,"started":traffic.starts_observed,"completed":traffic.completions_observed,
		"cancelled":traffic.cancellations_observed,"censored_retirements":traffic.censored_retirements,"censored_at_end":traffic.unresolved_changes(),
		"max_pending_seconds":traffic.maximum_pending_seconds,"legacy_wall_frames":legacy_wall_frames,
		"legacy_no_escape_seconds":legacy_no_escape_seconds,"legacy_longest_blocked_seconds":legacy_longest_blocked,
		"input_observed":stats,"issue_counts":issues,"independent_issues":independent_issues,
		"first_issues":{"npc":traffic.first_issue_snapshot,"core":traffic.first_core_issue,"motion":traffic.first_motion_issue,"change":traffic.first_change_issue},
		"reachable_status":"not_audited","terminal_reason":"fixed_simulation_budget_reached",
		"scope":"pure traffic model, fixed center lane and three legacy longitudinal input curves; constant controller fuel isolates traffic, not Main resource termination or human playability"}
