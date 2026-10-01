extends SceneTree
## Integration evidence: only synthetic data in a unique tmp directory is read.
const MainScene = preload("res://scenes/main.tscn")
const Launcher = preload("res://tests/PlaytestLauncher.gd")
const Config = preload("res://tests/playtest_launch_config.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Recorder = preload("res://tests/playtest_session_recorder.gd")

var failures: Array[String] = []
var folder := "res://tmp/playtest-isolation-%d" % Time.get_ticks_usec()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create isolated fixture directory")
	var path := folder + "/synthetic-career.cfg"
	var store := SaveStore.new(path)
	var fixture := SaveStore.default_data()
	fixture.career.runs = 9
	fixture.career.total_distance = 1234.0
	fixture.settings.music_volume = 0.35
	_check(store.save_data(fixture), "Create synthetic formal-save sentinel")
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	_check(not main.persistence_enabled, "SceneTree launch must default to no real save load")
	main._configure_persistence(store, true)
	main._set_audio_channel_volume(&"Music", 0.4)
	_check(is_equal_approx(store.load_data().settings.music_volume, 0.4), "Positive control: enabled persistence really writes fixture")
	_check(store.save_data(fixture), "Restore synthetic baseline")
	main._configure_persistence(store, true)
	var before := FileAccess.get_sha256(path)
	var config := Config.parse(PackedStringArray(["neon_coast", "pulse_gt", "standard", "611"]))
	Launcher.configure_main(main, config)
	_check(not main.persistence_enabled, "Launcher must disable even an enabled injected store")
	var recorder = Recorder.new()
	recorder.source_main = main
	recorder.source_label = "automated_headless"
	recorder.output_path = folder + "/results.jsonl"
	main.add_child(recorder)
	recorder.set_process(false)
	recorder._process(0)
	main._process(3.0)
	main._process(0.1)
	main.run.award_coin()
	recorder._process(0)
	_check(main.run.phase == main.RunState.Phase.RUNNING and main.run.distance > 0, "Real Main driving must progress")
	main._pause_run()
	main._show_pause_settings()
	main.settings_audio_panel.get_node("Music/Slider").value = 15
	main.settings_audio_panel.get_node("Effects/Slider").value = 85
	main._cycle_difficulty()
	main._toggle_high_contrast()
	main._toggle_reduced_flashing()
	main._toggle_screen_shake()
	main._set_language_preference("en")
	main._save_tour_selection()
	main._close_submenu()
	main._resume_run()
	main._process(3.0)
	main.run.mark_clear()
	main._update_hud()
	var runs_after_result: int = main.save_data.career.runs
	for repeat in range(3):
		main.run.fail_integrity()
		main.run.tick(1.0, 760.0, 760.0)
		main._update_hud()
		recorder._process(0)
	_check(main.run.phase == main.RunState.Phase.RUN_CLEAR, "Clear must not fall back to failure")
	_check(main.save_data.career.runs == runs_after_result, "Repeated HUD must persist result only once in memory")
	main._replay_run()
	recorder._process(0)
	main._process(3.0)
	main.run.fail_integrity()
	main._update_hud()
	recorder._process(0)
	main.run.mark_clear()
	_check(main.run.phase == main.RunState.Phase.GAME_OVER, "Failure must not change to clear")
	main._replay_run()
	recorder._process(0)
	main._process(3.0)
	main._process(0.1)
	recorder._process(0)
	main._pause_run()
	main._request_title()
	main._confirm_destructive_action()
	recorder._process(0)
	main.queue_free()
	await process_frame
	var rows := _rows(folder + "/results.jsonl")
	_check(rows.size() == 3, "Clear, failure and abandoned retry must each yield one record")
	if rows.size() == 3:
		_check(rows[0].outcome == "clear" and rows[1].outcome == "failed" and rows[2].outcome == "aborted", "Terminal outcomes must survive replay, title and exit")
	_check(FileAccess.get_sha256(path) == before and store.load_data() == fixture, "Settings, results, replay and exit must leave formal fixture byte-for-byte unchanged")
	_check(not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".bak"), "No save staging files should remain")
	for outcome in ["clear", "failed"]:
		for action in ["replay", "title"]:
			await _same_frame_terminal(config, outcome, action)
	await _initialization_and_consecutive_restarts(config)
	await _failed_log_does_not_stop_driving(config)
	for filename in ["synthetic-career.cfg", "results.jsonl", "not-a-directory"]:
		var target: String = folder + "/" + filename
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("PLAYTEST_ISOLATION checks complete; failures=", failures.size())
	print("TEST_COMPLETE test_playtest_isolation.gd")
	quit(0 if failures.is_empty() else 1)

func _same_frame_terminal(config: Dictionary, outcome: String, action: String) -> void:
	var failures_before := failures.size()
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	Launcher.configure_main(main, config)
	var recorder = Recorder.new()
	recorder.source_main = main
	recorder.source_label = "automated_headless"
	var log_path := folder + "/same-frame-%s-%s.jsonl" % [outcome, action]
	recorder.output_path = log_path
	main.add_child(recorder)
	recorder.set_process(false)
	main._process(3.0)
	main._process(0.1)
	recorder._process(0)
	if outcome == "clear":
		main.run.mark_clear()
	else:
		main.run.fail_integrity()
	main._update_hud()
	# A result action may run before this observer's next _process callback.
	if action == "replay":
		main._replay_run()
	else:
		main._return_to_title()
	recorder._process(0)
	main.queue_free()
	await process_frame
	var rows := _rows(log_path)
	_check(rows.size() == (2 if action == "replay" else 1), "%s then immediate %s must retain exactly one row per attempt" % [outcome, action])
	if not rows.is_empty():
		_check(rows[0].outcome == outcome, "Immediate %s must not downgrade the prior %s to aborted" % [action, outcome])
	if action == "replay" and rows.size() == 2:
		_check(rows[1].outcome == "aborted", "Closing an unfinished retry must record aborted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))
	print("M1_TERMINAL_CASE outcome=%s action=%s status=%s" % [outcome, action, "pass" if failures.size() == failures_before else "fail"])

func _initialization_and_consecutive_restarts(config: Dictionary) -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	var recorder = Recorder.new()
	recorder.source_main = main
	recorder.source_label = "automated_headless"
	var log_path := folder + "/consecutive-restarts.jsonl"
	recorder.output_path = log_path
	main.add_child(recorder)
	recorder.set_process(false)
	recorder._process(0)
	main._reset_run()
	main._reset_run()
	_check(not FileAccess.file_exists(log_path), "Title initialization and idle resets must not create phantom attempts")
	Launcher.configure_main(main, config)
	main._replay_run()
	main._replay_run()
	# Three real countdown attempts, including two same-frame abandoned retries.
	main.queue_free()
	await process_frame
	var rows := _rows(log_path)
	_check(rows.size() == 3, "Consecutive restart/exit must record exactly the three launched attempts")
	var seeds: Array = []
	for row in rows:
		_check(row.outcome == "aborted" and is_zero_approx(float(row.seconds)), "An unstarted retry must not acquire a phantom terminal result")
		_check(not seeds.has(row.seed), "A launched attempt must not be recorded twice")
		seeds.append(row.seed)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))

func _failed_log_does_not_stop_driving(config: Dictionary) -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	Launcher.configure_main(main, config)
	var blocker := FileAccess.open(folder + "/not-a-directory", FileAccess.WRITE)
	blocker.store_string("Synthetic file blocks use as a log directory")
	blocker.close()
	var recorder = Recorder.new()
	recorder.source_main = main
	recorder.source_label = "automated_headless"
	recorder.output_path = folder + "/not-a-directory/results.jsonl"
	main.add_child(recorder)
	recorder.set_process(false)
	main._process(3.0)
	recorder._process(0)
	main.run.fail_integrity()
	recorder._process(0)
	_check(recorder._write_failed, "Unwritable log destination must register a write failure")
	main._replay_run()
	recorder._process(0)
	main._process(3.0)
	main._process(0.2)
	_check(main.run.phase == main.RunState.Phase.RUNNING and main.run.distance > 0, "Logging failure must not prevent restart and driving")
	_check(not main.persistence_enabled, "Logging failure must never re-enable formal persistence")
	main.queue_free()
	await process_frame

func _rows(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			result.append(JSON.parse_string(line))
	return result

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error("PLAYTEST_ISOLATION: " + label)
