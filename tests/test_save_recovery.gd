extends SceneTree
## Synthetic saves only; the child mode interrupts its own save process.
const SaveStore = preload("res://scripts/save_store.gd")
const FailingSaveStore = preload("res://tests/failing_save_store.gd")

class DeniedReadStore extends SaveStore:
	var denied := true
	var deny_backup := false
	var denied_error: Error = ERR_FILE_NO_PERMISSION

	func _load_config(path: String, config: ConfigFile) -> Error:
		if path == save_path + (".bak" if deny_backup else "") and denied:
			return denied_error
		return super._load_config(path, config)

class InterruptedStore extends SaveStore:
	func _promote_temp_file(_temporary_path: String, target_path: String) -> Error:
		if FileAccess.file_exists(target_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))
		var marker := FileAccess.open(target_path + ".interrupted", FileAccess.WRITE)
		marker.store_string("TARGET_REMOVED_BEFORE_PROMOTE")
		marker.close()
		OS.kill(OS.get_process_id())
		return ERR_CANT_CREATE

var folder := "res://tmp/save-recovery-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var failures := 0
var owned_pid := -1

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2:
		_run_child(arguments[0], arguments[1])
		return
	_check(DirAccess.make_dir_recursive_absolute(folder) == OK, "isolated directory created")
	var original := _fixture(7)
	var newer := _fixture(11)
	var path := folder + "/priority.cfg"
	_seed(path, newer)
	_seed(path + ".bak", original)
	var priority := SaveStore.new(path)
	_check(priority.load_data() == newer and priority.last_load_status == &"primary", "valid primary wins over valid backup")

	path = folder + "/missing.cfg"
	_seed(path + ".bak", original)
	var before := FileAccess.get_sha256(path + ".bak")
	var missing := SaveStore.new(path)
	_check(missing.load_data() == original, "missing primary restores full valid backup")
	_check(missing.last_load_status == &"backup", "backup recovery reports its source")
	_check(not FileAccess.file_exists(path) and FileAccess.get_sha256(path + ".bak") == before, "recovery load is read-only")

	path = folder + "/damaged.cfg"
	_invalid(path)
	_seed(path + ".bak", original)
	_check(SaveStore.new(path).load_data() == original, "invalid primary restores full valid backup")
	var broken_hash := FileAccess.get_sha256(path)
	before = FileAccess.get_sha256(path + ".bak")
	var failing := FailingSaveStore.new(path)
	_check(failing.load_data() == original, "failed-save fixture starts from recovered state")
	_check(not failing.save_data(newer), "promotion failure returns false")
	_check(SaveStore.new(path).load_data() == original, "failed promotion preserves the only valid data")
	_check(FileAccess.file_exists(path + ".bak") and FileAccess.get_sha256(path + ".bak") == before, "failed promotion never overwrites or deletes the sole valid backup")

	path = folder + "/recovered-save.cfg"
	_invalid(path)
	_seed(path + ".bak", original)
	var recovered := SaveStore.new(path)
	_check(recovered.load_data() == original, "recovered save loads backup first")
	_check(recovered.save_data(newer), "next save after recovery succeeds")
	_check(SaveStore.new(path).load_data() == newer, "next save publishes new full data")
	_check(SaveStore.new(path + ".bak").load_data() == original, "next save preserves the known-good backup rather than corrupt primary")
	_check(SaveStore.new(path).save_data(_fixture(12)), "following normal save succeeds")
	_check(SaveStore.new(path + ".bak").load_data() == newer, "following normal save rotates a validated primary into backup")

	path = folder + "/invalid-both.cfg"
	_invalid(path)
	_invalid(path + ".bak")
	broken_hash = FileAccess.get_sha256(path)
	before = FileAccess.get_sha256(path + ".bak")
	var invalid := SaveStore.new(path)
	_check(invalid.load_data() == SaveStore.default_data() and invalid.last_load_status == &"invalid", "both invalid files produce safe in-memory defaults and explicit invalid status")
	_check(FileAccess.get_sha256(path) == broken_hash and FileAccess.get_sha256(path + ".bak") == before, "invalid pair is never silently rewritten on load")
	_check(not invalid.save_data(SaveStore.default_data()) and invalid.last_save_error == ERR_INVALID_DATA, "invalid-load defaults cannot overwrite damaged evidence")
	_check(not SaveStore.new(path).save_data(newer), "new store cannot bypass invalid disk-state protection")
	_check(FileAccess.get_sha256(path) == broken_hash and FileAccess.get_sha256(path + ".bak") == before and not FileAccess.file_exists(path + ".tmp"), "blocked invalid saves preserve both files without a temporary write")

	path = folder + "/invalid-single.cfg"
	_invalid(path)
	before = FileAccess.get_sha256(path)
	_check(not SaveStore.new(path).save_data(newer), "invalid primary without a backup cannot be silently overwritten")
	_check(FileAccess.get_sha256(path) == before, "single damaged file remains available for diagnosis")

	path = folder + "/invalid-backup-only.cfg"
	_invalid(path + ".bak")
	before = FileAccess.get_sha256(path + ".bak")
	_check(not SaveStore.new(path).save_data(newer), "missing primary with invalid backup is not mistaken for a fresh profile")
	_check(not FileAccess.file_exists(path) and FileAccess.get_sha256(path + ".bak") == before, "invalid backup-only evidence stays intact")

	path = folder + "/denied.cfg"
	_seed(path, newer)
	_seed(path + ".bak", original)
	broken_hash = FileAccess.get_sha256(path)
	before = FileAccess.get_sha256(path + ".bak")
	var denied := DeniedReadStore.new(path)
	_check(denied.load_data() == SaveStore.default_data(), "primary read permission failure is not interpreted as corruption or backup recovery")
	_check(denied.last_load_status == &"io_error", "permission failure is reported separately from invalid data")
	_check(not denied.save_data(_fixture(99)) and denied.last_save_error == ERR_FILE_NO_PERMISSION, "unreadable primary blocks unsafe overwrite with its original error")
	_check(FileAccess.get_sha256(path) == broken_hash and FileAccess.get_sha256(path + ".bak") == before, "permission failure preserves primary and backup byte-for-byte")
	denied.denied = false
	_check(not denied.save_data(SaveStore.default_data()), "access returning does not let unrefreshed fallback defaults replace the old career")
	_check(FileAccess.get_sha256(path) == broken_hash and FileAccess.get_sha256(path + ".bak") == before, "failed-load write protection survives transient error recovery")
	_check(denied.load_data() == newer, "explicit reload can recover after a transient read error")
	_check(denied.save_data(_fixture(12)), "successful reload permits later intentional save")
	_check(denied.last_save_error == OK, "successful save clears the previous save failure")

	path = folder + "/backup-read-error.cfg"
	_invalid(path)
	_seed(path + ".bak", original)
	before = FileAccess.get_sha256(path + ".bak")
	var backup_error := DeniedReadStore.new(path)
	backup_error.deny_backup = true
	backup_error.denied_error = ERR_FILE_CANT_READ
	_check(backup_error.load_data() == SaveStore.default_data() and backup_error.last_load_status == &"io_error", "backup read failure is not treated as invalid data")
	backup_error.denied = false
	_check(not backup_error.save_data(newer) and backup_error.last_save_error == ERR_FILE_CANT_READ, "transient backup I/O failure also locks fallback state until reload")
	_check(FileAccess.get_sha256(path + ".bak") == before, "unrefreshed backup fallback never overwrites the old career")
	_check(backup_error.load_data() == original and backup_error.save_data(newer), "explicit successful backup reload permits saving")

	path = folder + "/unloaded-read-error.cfg"
	_seed(path, original)
	before = FileAccess.get_sha256(path)
	var unloaded := DeniedReadStore.new(path)
	_check(not unloaded.save_data(newer), "save checks disk access even when load was never called")
	_check(FileAccess.get_sha256(path) == before, "preflight read error does not touch the primary")

	path = folder + "/write-failure.cfg"
	_seed(path, original)
	_check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp")) == OK, "write failure uses an isolated directory at the temporary-file path")
	_check(not SaveStore.new(path).save_data(newer), "temporary file write failure reports false")
	_check(SaveStore.new(path).load_data() == original, "write failure preserves prior complete data")

	path = folder + "/interruption.cfg"
	_seed(path, original)
	var interrupted: bool = await _child("interrupt", path, false)
	_check(interrupted and FileAccess.file_exists(path + ".interrupted") and FileAccess.file_exists(path + ".tmp"), "real child stopped after removing primary before promotion")
	_check(not FileAccess.file_exists(path), "interrupted process did not restore primary on its way out")
	_check(await _child("recover", path, true), "new process restores full backup and safely saves again")
	print("SAVE_RECOVERY_CHECKS_COMPLETE failures=%d" % failures)
	print("TEST_COMPLETE test_save_recovery.gd")
	quit(0 if failures == 0 else 1)

func _fixture(runs: int) -> Dictionary:
	var data := SaveStore.default_data()
	data.settings.language = "en"
	data.settings.music_volume = 0.23
	data.settings.effects_volume = 0.71
	data.settings.difficulty = 2
	data.settings.reduced_flashing = true
	data.career.runs = runs
	data.career.total_distance = 4321.5
	data.top_scores = [{"score": 7000 + runs, "difficulty": 2, "distance": 3200.0, "date": "synthetic"}]
	data.tour.track_results.neon_coast = {"cleared": true, "best_score": 7000, "best_time": 150.5, "medal": 2}
	data.ratings = {&"neon_coast": {"total": 75, "grade": "B"}}
	return data

func _seed(path: String, data: Dictionary) -> void:
	_check(SaveStore.new(path).save_data(data), "write synthetic fixture: " + path.get_file())

func _invalid(path: String) -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SaveStore.CURRENT_VERSION)
	config.set_value("settings", "audio_volume", "invalid type")
	_check(config.save(path) == OK, "write invalid synthetic fixture")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("SAVE_RECOVERY_FAIL " + message)

func _run_child(mode: String, path: String) -> void:
	# Refuse arbitrary CLI targets: every child can touch only its parent's fixture.
	if not path.begins_with("res://tmp/save-recovery-") or path.get_file() != "interruption.cfg":
		quit(2)
		return
	if mode == "interrupt":
		InterruptedStore.new(path).save_data(_fixture(11))
		quit(3)
	elif mode == "recover":
		var store := SaveStore.new(path)
		_check(store.load_data() == _fixture(7), "cross-process recovery preserves all fields")
		_check(store.save_data(_fixture(11)), "post-recovery save succeeds in new process")
		_check(SaveStore.new(path).load_data() == _fixture(11), "post-recovery primary round-trips")
		_check(SaveStore.new(path + ".bak").load_data() == _fixture(7), "post-recovery backup stays valid")
		print("SAVE_RECOVERY_CHILD_COMPLETE failures=%d" % failures)
		quit(0 if failures == 0 else 1)
	else:
		quit(2)

func _child(mode: String, path: String, expect_success: bool) -> bool:
	var log_path := folder + "/" + mode + ".log"
	owned_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", ProjectSettings.globalize_path(log_path),
		"--script", "res://tests/test_save_recovery.gd", "--", mode, path
	]), false)
	if owned_pid <= 0:
		return false
	var child_pid := owned_pid
	var deadline := Time.get_ticks_msec() + 9000
	var timed_out := false
	while OS.is_process_running(child_pid):
		if Time.get_ticks_msec() >= deadline:
			timed_out = true
			OS.kill(child_pid)
			break
		await process_frame
	var cleanup_deadline := Time.get_ticks_msec() + 1000
	while OS.is_process_running(child_pid) and Time.get_ticks_msec() < cleanup_deadline:
		await process_frame
	var running := OS.is_process_running(child_pid)
	var code := -1 if running else OS.get_process_exit_code(child_pid)
	if not running:
		owned_pid = -1
	var output := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
	var script_failure := output.contains("SCRIPT ERROR:") or output.contains("Parse Error:") or output.contains("Assertion failed:")
	print("SAVE_RECOVERY_CHILD mode=%s exit=%d timeout=%s" % [mode, code, timed_out])
	if expect_success:
		return not timed_out and not running and code == 0 and not script_failure and output.contains("SAVE_RECOVERY_CHILD_COMPLETE failures=0")
	# Windows TerminateProcess may report zero; interruption is proven by the
	# flushed marker, absent primary, and unpromoted temporary file above.
	return not timed_out and not running and code != 3 and not script_failure

func _finalize() -> void:
	if owned_pid > 0 and OS.is_process_running(owned_pid):
		OS.kill(owned_pid)
