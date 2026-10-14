extends SceneTree
## External test driver only. Main receives real frame time and physical input.
## No manual ticks, fuel/hull injection, traffic placement, or forced outcomes.
const MainScene = preload("res://scenes/main.tscn")
const Contract = preload("res://scripts/tests/SoakContract.gd")
const Pilot = preload("res://tests/test_dynamic_pickup_smoke.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Cars = preload("res://scripts/catalog/vehicle_catalog.gd")
const ExportAudit = preload("res://scripts/tests/ExportResourceAudit.gd")
var main
var folder := ""
var pilot := false
var started := 0
var last_usec := 0
var driving_wall := 0.0
var source := {}
var pressed := {}
var errors: Array[String] = []
var samples: FileAccess
var runs := 0
var returns := 0
var outcomes: Array[Dictionary] = []
var title_nodes: Array[int] = []
var tracks_seen := {}
var cars_seen := {}
var difficulties_seen := {}
var last_sample := -1.0
var previous_phase := -1
var previous_distance := 0.0
var phase_since := 0.0
var pause_tested := false
var capture_once := {}
var throttle := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [1,2] or (args.size() == 2 and args[1] != "--pilot") or DisplayServer.get_name() == "headless":
		push_error("Usage: graphical Godot --script RealtimeSoak.gd -- <new evidence directory> [--pilot]")
		quit(2)
		return
	folder = args[0]
	pilot = args.size() == 2
	if DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("Soak requires a new evidence directory")
		quit(2)
		return
	samples = FileAccess.open(folder.path_join("samples.jsonl"), FileAccess.WRITE)
	if samples == null: quit(2); return
	source = _source_hashes()
	DisplayServer.window_set_size(Vector2i(1920,1080))
	root.content_scale_size = Vector2i(1280,720)
	main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main) # Not current_scene: Main's normal persistence gate stays off.
	main._set_language_preference("zh")
	if main.persistence_enabled: _error("Unexpected persistence enabled")
	started = Time.get_ticks_usec()
	last_usec = started
	print("REALTIME_SOAK_STARTED ", JSON.stringify({"pid":OS.get_process_id(),"pilot":pilot,"folder":folder,"source":source,
		"scope":"external driver / production Main / graphical real time / no formal save / not normal EXE entry or human playtest"}))
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var wall := (now-started)/1000000.0
		var gap := (now-last_usec)/1000000.0
		last_usec = now
		var phase: int = main.run.phase
		if Contract.moving_frame(previous_phase == main.RunState.Phase.RUNNING,previous_distance,main.run.distance,gap):
			driving_wall += gap
		previous_distance = main.run.distance
		if phase != previous_phase:
			phase_since = wall
			_release_keys()
			if phase in [main.RunState.Phase.GAME_OVER, main.RunState.Phase.RUN_CLEAR]:
				outcomes.append({"run":runs,"track":String(main.current_track.id),"car":String(main.current_vehicle.id),"difficulty":main.difficulty_index,
					"seed":main.current_run_seed,"phase":main.RunState.Phase.keys()[phase],"seconds":main.run.elapsed_seconds,"distance":main.run.distance,
					"fuel":main.run.fuel,"hull":main.integrity.current,"collisions":main.run.collisions,"coins":main.run.coins})
				print("REALTIME_SOAK_OUTCOME ", JSON.stringify(outcomes.back()))
		previous_phase = phase
		if wall-last_sample >= 1.0:
			last_sample = wall
			_sample(wall,phase)
		if main.traffic.has_vehicle_overlap(): _error("NPC body overlap")
		if main.traffic.has_full_lane_wall(): _error("Three-lane wall")
		if phase == main.RunState.Phase.TITLE and wall-phase_since >= 0.5:
			title_nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			_start_next()
		elif phase == main.RunState.Phase.RUNNING:
			if not pause_tested and main.run.elapsed_seconds > 12.0:
				pause_tested = true
				_key(KEY_SPACE,true)
			else: _drive()
		elif phase == main.RunState.Phase.PAUSED and wall-phase_since > 1.0:
			main.get_node("CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton").pressed.emit()
		elif phase in [main.RunState.Phase.GAME_OVER,main.RunState.Phase.RUN_CLEAR] and wall-phase_since > 1.0:
			main.get_node("CanvasLayer/ResultScreen/Center/Card/Content/TitleButton").pressed.emit()
			returns += 1
		if phase == main.RunState.Phase.RUNNING and main.run.elapsed_seconds > 180.0: _error("Natural run exceeded 180 seconds")
		# Do not read/hash every resource on every driving frame. Final identity
		# is checked at completion; inexpensive counters determine when to finish.
		var covered := not pilot and driving_wall >= 1800.0 and returns >= 20 and outcomes.size() >= 20 and tracks_seen.size() == 4 and cars_seen.size() == 6 and difficulties_seen.size() == 3
		if not errors.is_empty() or covered or (pilot and wall >= 150.0) or (not pilot and wall >= 2400.0):
			await _finish(_summary(wall))
			return

func _start_next() -> void:
	main.save_data.tour.selected_track_id = Tracks.all()[int(runs/3)%4].id
	main.save_data.tour.selected_vehicle_id = Cars.all()[runs%6].id
	main.difficulty_index = runs%3
	main._start_new_run() # Configuration driver, not a claim to test unlock UI.
	runs += 1
	pause_tested = false
	tracks_seen[String(main.current_track.id)] = true
	cars_seen[String(main.current_vehicle.id)] = true
	difficulties_seen[main.difficulty_index] = true

func _drive() -> void:
	var player_y: float = main.TrackGeometry.player_y(main.get_viewport_rect().size.y)
	var x: float = main.drive.lateral_position
	var target := x
	var choices: Array = main.fuel_pickups if main.run.fuel < 65.0 else main.coin_director.coins
	if main.integrity.current < 70.0 and main.run.fuel > 30.0: choices = main.repair_supplies.pickups
	var closest := -INF
	for pickup in choices:
		if pickup.y < 0 or pickup.y > player_y+30 or pickup.y < closest: continue
		closest = pickup.y
		var lane: float = pickup.lane_position if pickup.get("lane_position") != null else float(pickup.lane)
		target = (lane-1.0)*260.0
	var obstacles: Array = []
	for npc in main.traffic.vehicles:
		if npc.y+npc.half_length < 0 or npc.y-npc.half_length > 720: continue
		obstacles.append({"x":(npc.lane_position-1.0)*260.0,"y":npc.y,"speed":npc.actual_world_speed,"vx":npc.lateral_velocity,
			"target_x":(float(npc.target_lane)-1.0)*260.0,"warning_delay":npc.warning_remaining,
			"intent_lateral_speed":624.0 if npc.lane_change_enabled else 0.0})
	for core in main.traffic.lane_events.core_markers(720):
		obstacles.append({"x":(core.x-1.5)*260.0,"y":core.y,"speed":0.0,"vx":0.0,"target_x":(core.x-1.5)*260.0,"half_x":148.0,"half_y":75.0})
	var authority: float = main.drive.steering_speed*main.drive.speed_steering_multiplier()*main.integrity.steering_multiplier()
	var best := INF
	var safe := x
	for candidate in [target,x,-330.0,-260.0,-130.0,0.0,130.0,260.0,330.0]:
		if not Pilot.pilot_route_safe(x,player_y,main.drive.speed,authority,float(candidate),obstacles): continue
		var score: float = absf(candidate-target)+absf(candidate-x)*0.15
		if score < best: best = score; safe = candidate
	_key(KEY_A, safe < x-8.0)
	_key(KEY_D, safe > x+8.0)
	_key(KEY_S, is_inf(best))
	throttle = Contract.throttle_held(throttle,main.drive.speed,main.drive.max_speed)
	var accelerating: bool = not is_inf(best) and throttle
	# One deliberately spaced physical double-tap, not direct overdrive calls.
	if main.run.elapsed_seconds >= 8.0 and main.run.elapsed_seconds < 8.1: accelerating = false
	if main.run.elapsed_seconds >= 8.1 and main.run.elapsed_seconds < 8.2: accelerating = true
	if main.run.elapsed_seconds >= 8.2 and main.run.elapsed_seconds < 8.3: accelerating = false
	if main.run.elapsed_seconds >= 8.3 and main.run.elapsed_seconds < 8.4: accelerating = true
	_key(KEY_W, accelerating)

func _key(key: int, down: bool) -> void:
	if bool(pressed.get(key,false)) == down: return
	pressed[key] = down
	Input.parse_input_event(Contract.key_event(key,down))
	Input.flush_buffered_events()

func _release_keys() -> void:
	for key in pressed.keys(): _key(key,false)

func _sample(wall: float, phase: int) -> void:
	var row := {"wall_seconds":wall,"driving_wall_seconds":driving_wall,"runs":runs,"returns":returns,"phase":main.RunState.Phase.keys()[phase],
		"track":String(main.current_track.id),"car":String(main.current_vehicle.id),"difficulty":main.difficulty_index,"speed":main.drive.speed,
		"distance":main.run.distance,"fuel":main.run.fuel,"hull":main.integrity.current,"construction":main.traffic.lane_events.state!=0,
		"overdrive":main.overdrive.is_active(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),
		"static_memory":Performance.get_monitor(Performance.MEMORY_STATIC),"fps":Performance.get_monitor(Performance.TIME_FPS)}
	samples.store_line(JSON.stringify(row))
	samples.flush()
	var key := "%s-%s" % [row.track,"construction" if row.construction else "driving"]
	if phase == main.RunState.Phase.RUNNING and not capture_once.has(key):
		capture_once[key] = true
		_capture.call_deferred(key)

func _capture(key: String) -> void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(folder.path_join(key+".png")) != OK: _error("Screenshot write failed")

func _source_hashes() -> Dictionary:
	var hashes := {}
	var paths := ExportAudit.runtime_manifest()
	paths.append_array(PackedStringArray(["res://project.godot","res://scripts/tests/SoakContract.gd","res://scripts/tests/ExportResourceAudit.gd","res://tests/test_dynamic_pickup_smoke.gd",get_script().resource_path]))
	for path in paths:
		hashes[path] = FileAccess.get_sha256(path)
	return hashes

func _summary(wall: float) -> Dictionary:
	var drift := 0
	if title_nodes.size() >= 12:
		drift = title_nodes.back()-title_nodes[11] # All track textures warmed once.
	return {"pilot":pilot,"wall_seconds":wall,"driving_wall_seconds":driving_wall,"runs":runs,"returns":returns,"outcomes":outcomes.size(),"outcome_rows":outcomes,
		"tracks":tracks_seen.size(),"cars":cars_seen.size(),"difficulties":difficulties_seen.size(),"source_stable":source==_source_hashes(),
		"errors":errors,"title_node_drift":drift,"title_nodes":title_nodes,"source":source}

func _error(message: String) -> void:
	if not errors.has(message): errors.append(message); push_error("REALTIME_SOAK "+message)

func _finish(summary: Dictionary) -> void:
	_release_keys()
	summary.missing_coverage = Contract.missing_coverage(summary)
	summary.full_pass = not pilot and summary.missing_coverage.is_empty()
	var file := FileAccess.open(folder.path_join("summary.json"),FileAccess.WRITE)
	if file == null: _error("Summary write failed")
	else: file.store_string(JSON.stringify(summary,"\t")); file.close()
	samples.close()
	print("REALTIME_SOAK_COMPLETE ", JSON.stringify(summary))
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	quit(0 if errors.is_empty() and summary.source_stable and (summary.full_pass or (pilot and summary.outcomes>=1 and summary.driving_wall_seconds>=60)) else 1)
