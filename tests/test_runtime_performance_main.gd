extends SceneTree
## Fresh child APPDATA only; synthetic states do not count as actual driving.
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
const SWITCH := "NEON_COAST_PERF_CAPTURE"
var folder := "res://tmp/perf-main-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var owned_pid := -1
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 3 and args[0] == "--isolated-child":
		await _child(args[1], args[2])
		return
	for mode in ["unset", "0", "1", "true"]:
		await _launch(mode)
	print("PERFORMANCE_MAIN_EVIDENCE " + folder)
	_finish(false)

func _launch(mode: String) -> void:
	var appdata := _canonical(ProjectSettings.globalize_path(folder + "/" + mode + "/appdata"))
	_check(DirAccess.make_dir_recursive_absolute(appdata) == OK, "create owned isolated APPDATA")
	var originals := {}
	for key in ["APPDATA", SWITCH]:
		originals[key] = {"exists": OS.has_environment(key), "value": OS.get_environment(key)}
	OS.set_environment("APPDATA", appdata)
	if mode == "unset":
		OS.unset_environment(SWITCH)
	else:
		OS.set_environment(SWITCH, mode)
	var log_path := ProjectSettings.globalize_path(folder + "/" + mode + "/child.log")
	owned_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", log_path,
		"--script", "res://tests/test_runtime_performance_main.gd", "--", "--isolated-child", appdata, mode
	]), false)
	for key in originals:
		if originals[key].exists:
			OS.set_environment(key, originals[key].value)
		else:
			OS.unset_environment(key)
		_check(OS.has_environment(key) == originals[key].exists and OS.get_environment(key) == originals[key].value, "restore parent environment immediately: " + key)
	if owned_pid <= 0:
		_check(false, "child process starts")
		return
	var deadline := Time.get_ticks_msec() + 9000
	var timed_out := false
	while OS.is_process_running(owned_pid):
		if Time.get_ticks_msec() >= deadline:
			timed_out = true
			OS.kill(owned_pid)
			break
		await process_frame
	var cleanup_deadline := Time.get_ticks_msec() + 1000
	while OS.is_process_running(owned_pid) and Time.get_ticks_msec() < cleanup_deadline:
		await process_frame
	var running := OS.is_process_running(owned_pid)
	var code := -1 if running else OS.get_process_exit_code(owned_pid)
	if not running:
		owned_pid = -1
	var output := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
	_check(not running and not timed_out and code == 0 and "PERFORMANCE_MAIN_CHILD_COMPLETE failures=0" in output.split("\n") and not output.contains("SCRIPT ERROR:"), "child completes accurately: " + mode)
	print(output)
	print("PERFORMANCE_MAIN_CHILD mode=%s exit=%d timeout=%s" % [mode, code, timed_out])

func _child(expected_appdata: String, mode: String) -> void:
	var expected := _canonical(expected_appdata)
	var base := expected.get_base_dir().get_base_dir()
	var project_tmp := _canonical(ProjectSettings.globalize_path("res://tmp"))
	var valid := expected.get_file() == "appdata" and expected.get_base_dir().get_file() == mode and base.get_file().begins_with("perf-main-") and base.get_base_dir() == project_tmp
	_check(valid and _canonical(OS.get_environment("APPDATA")) == expected and _canonical(OS.get_user_data_dir()).begins_with(expected + "/") and _canonical(ProjectSettings.globalize_path("user://")) == _canonical(OS.get_user_data_dir()), "user directory is isolated before loading Main")
	if failures > 0:
		_finish(true)
		return
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in range(5):
		await process_frame
		if current_scene != null and current_scene.is_node_ready():
			break
	var main = current_scene
	_check(main != null and main.has_method("_capture_runtime_performance"), "normal Main exposes passive capture integration")
	if main == null:
		_finish(true)
		return
	main.set_process(false)
	if not main.has_method("_capture_runtime_performance"):
		await _dispose(main)
		_finish(true)
		return
	var capture = main.runtime_capture
	if mode == "1":
		_check(capture != null and capture.active, "exact opt-in enables normal main-scene capture")
		if capture != null:
			main.run.phase = main.RunState.Phase.PAUSED
			var before := _snapshot(main)
			main._capture_runtime_performance()
			_check(_snapshot(main) == before, "sampling does not mutate gameplay, RNG, inputs or save data")
			main.result_persisted = true # Do not save fake results while testing early returns.
			for phase in [main.RunState.Phase.COUNTDOWN, main.RunState.Phase.RUNNING, main.RunState.Phase.PAUSED, main.RunState.Phase.GAME_OVER, main.RunState.Phase.RUN_CLEAR]:
				main.run.phase = phase
				main._process(0.0)
			var runs_before: int = main.capture_run_number
			main._reset_run(777)
			_check(main.capture_run_number == runs_before, "resetting alone is not a new race start")
			main._restart_run()
			_check(main.capture_run_number == runs_before + 1, "real restart counts exactly one new race")
			main._return_to_title()
			_check(main.capture_run_number == runs_before + 1, "returning to title does not forge another race")
			main._capture_runtime_performance()
			var count_before: int = capture.sample_count
			var secondary = load("res://scenes/main.tscn").instantiate()
			root.add_child(secondary)
			secondary.set_process(false)
			_check(secondary.runtime_capture == null, "non-current test Main cannot start another capture")
			await _dispose(secondary)
			var output_path: String = capture.output_path
			await _dispose(main)
			_check(not capture.active, "Main exit closes capture")
			var output := FileAccess.get_file_as_string(output_path)
			for phase in ["title", "countdown", "running", "paused", "game_over", "run_clear"]:
				_check(output.contains('"phase":"%s"' % phase), "early-return phase is recorded: " + phase)
			_check(output.contains('"run_number":1') and output.contains('"reset_number":3') and count_before >= 6, "race starts and resets have distinct observable counters")
			_check(output.contains('"event":"capture_closed"') and output.contains('"focused":') and output.contains('"window_width":'), "terminal and actual window context are present")
	else:
		_check(capture == null and not DirAccess.dir_exists_absolute("user://performance"), "default and non-exact switches do no diagnostic IO")
		await _dispose(main)
	_check(not FileAccess.file_exists("user://save.cfg"), "sampling did not create a save")
	_finish(true)

func _snapshot(main) -> Array:
	return [main.run.phase, main.run.fuel, main.run.distance, main.run.score, main.drive.speed, main.drive.lateral_position, main.run_seed_sequence._random.state, main.traffic._random.state, main.current_run_seed, main.save_data.duplicate(true), main.forward_keys_down.duplicate()]

func _dispose(main) -> void:
	var refs := AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, refs), "isolated audio retires")

func _canonical(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("PERFORMANCE_MAIN_FAIL " + message)

func _finish(child: bool) -> void:
	print("PERFORMANCE_MAIN_CHILD_COMPLETE failures=%d" % failures if child else "TEST_COMPLETE test_runtime_performance_main.gd")
	quit(0 if failures == 0 else 1)

func _finalize() -> void:
	if owned_pid > 0 and OS.is_process_running(owned_pid):
		OS.kill(owned_pid)
