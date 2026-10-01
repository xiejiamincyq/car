extends SceneTree
## Real writer/reader processes; the only writable save is a synthetic tmp fixture.
const SaveStore = preload("res://scripts/save_store.gd")
var folder := "res://tmp/persistence-restart-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var owned_pid := -1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		quit(1)
		return
	var path := folder + "/synthetic-save.cfg"
	var fixture := SaveStore.default_data()
	fixture.career.runs = 9
	fixture.career.total_distance = 1250.0
	if not SaveStore.new(path).save_data(fixture):
		quit(1)
		return
	var before := FileAccess.get_sha256(path)
	var success: bool = await _stage("writer", path)
	var after_writer := FileAccess.get_sha256(path)
	success = success and after_writer != before
	if success:
		success = await _stage("reader", path)
		success = success and FileAccess.get_sha256(path) == after_writer
	if not success:
		push_error("Cross-process persistence failed; isolated evidence retained at " + folder)
	else:
		for filename in ["synthetic-save.cfg", "synthetic-save.cfg.tmp", "synthetic-save.cfg.bak", "writer.log", "reader.log"]:
			var target: String = folder + "/" + filename
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("TEST_COMPLETE test_persistence_restart.gd")
	quit(0 if success else 1)

func _stage(mode: String, path: String) -> bool:
	var log_path := folder + "/" + mode + ".log"
	owned_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", ProjectSettings.globalize_path(log_path),
		"--script", "res://tests/support/persistence_restart_fixture.gd", "--", mode, path
	]), false)
	if owned_pid <= 0:
		return false
	var child_pid := owned_pid
	# Nine seconds to run plus at most one second to confirm termination.
	var deadline := Time.get_ticks_msec() + 9000
	var timed_out := false
	while OS.is_process_running(child_pid):
		if Time.get_ticks_msec() >= deadline:
			timed_out = true
			# Never search for or stop other Godot instances.
			var kill_error := OS.kill(child_pid)
			print("PERSISTENCE_CHILD_TIMEOUT mode=%s pid=%d kill_error=%d" % [mode, child_pid, kill_error])
			break
		await process_frame
	# A terminated child must not be left behind, including on the timeout path.
	var cleanup_deadline := Time.get_ticks_msec() + 1000
	while OS.is_process_running(child_pid) and Time.get_ticks_msec() < cleanup_deadline:
		await process_frame
	var still_running := OS.is_process_running(child_pid)
	var exit_code := -1 if still_running else OS.get_process_exit_code(child_pid)
	if not still_running:
		owned_pid = -1
	var output := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
	var marker := "PERSISTENCE_%s_COMPLETE" % mode.to_upper()
	var script_error := false
	for token in ["SCRIPT ERROR:", "Assertion failed:", "Parse Error:", "Failed to load script"]:
		script_error = script_error or output.contains(token)
	var success := not timed_out and not still_running and exit_code == 0 and not script_error and marker in output.split("\n")
	print("PERSISTENCE_CHILD mode=%s pid=%d exit=%d complete=%s" % [mode, child_pid, exit_code, success])
	if success:
		print(marker)
		if output.contains("WARNING:") or output.contains("ERROR:"):
			print(output)
	else:
		push_error(output)
	return success

func _finalize() -> void:
	if owned_pid > 0 and OS.is_process_running(owned_pid):
		OS.kill(owned_pid)
