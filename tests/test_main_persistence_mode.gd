extends SceneTree
## Real current_scene lifecycle, only after a fresh child verifies user:// isolation.
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
const SaveStore = preload("res://scripts/save_store.gd")

var folder := "res://tmp/main-persistence-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var owned_pid := -1
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 3 and arguments[0] == "--isolated-child":
		await _run_child(arguments[1],arguments[2])
		return
	if OS.get_name() != "Windows":
		_check(false, "APPDATA isolation fixture requires Windows")
		_finish()
		return
	var isolated_appdata := _canonical(ProjectSettings.globalize_path(folder + "/appdata"))
	if DirAccess.make_dir_recursive_absolute(isolated_appdata) != OK:
		_check(false, "create unique synthetic APPDATA directory")
		_finish()
		return
	for stage in ["create","reopen"]:
		await _launch_child(isolated_appdata,stage)
	_finish()

func _launch_child(isolated_appdata: String,stage: String) -> void:
	var log_path := ProjectSettings.globalize_path(folder + "/"+stage+".log")
	var had_appdata := OS.has_environment("APPDATA")
	var original_appdata := OS.get_environment("APPDATA")
	# The engine resolves/caches user:// during startup. Set the environment for
	# a fresh child, not after startup in the process that will load Main.
	OS.set_environment("APPDATA", isolated_appdata)
	owned_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", log_path,
		"--script", "res://tests/test_main_persistence_mode.gd", "--",
		"--isolated-child", isolated_appdata,stage
	]), false)
	if had_appdata:
		OS.set_environment("APPDATA", original_appdata)
	else:
		OS.unset_environment("APPDATA")
	_check(OS.has_environment("APPDATA") == had_appdata and OS.get_environment("APPDATA") == original_appdata, "parent APPDATA is immediately restored")
	if owned_pid <= 0:
		_check(false, "launch isolated lifecycle child")
		_finish()
		return
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
	var script_error := output.contains("SCRIPT ERROR:") or output.contains("Parse Error:") or output.contains("Assertion failed:") or output.contains("Failed to load script")
	var complete := "MAIN_PERSISTENCE_CHILD_COMPLETE failures=0" in output.split("\n")
	_check(not timed_out and not running and code == 0 and not script_error and complete, "isolated real lifecycle child reaches its terminal proof")
	print(output)
	print("MAIN_PERSISTENCE_CHILD stage=%s exit=%d timeout=%s evidence=%s" % [stage,code, timed_out, folder])

func _run_child(expected_appdata: String,stage: String) -> void:
	var expected := _canonical(expected_appdata)
	var project_tmp := _canonical(ProjectSettings.globalize_path("res://tmp"))
	var valid_target := expected.get_file() == "appdata" and expected.get_base_dir().get_file().begins_with("main-persistence-") and expected.get_base_dir().get_base_dir() == project_tmp
	# Fail closed before preloading/instantiating Main or touching any save.
	var user_dir := _canonical(OS.get_user_data_dir())
	var global_user_dir := _canonical(ProjectSettings.globalize_path("user://"))
	var isolated := valid_target and _canonical(OS.get_environment("APPDATA")) == expected and user_dir.begins_with(expected + "/") and global_user_dir == user_dir
	_check(isolated, "both OS and user:// resolve inside the expected synthetic APPDATA")
	if not isolated:
		_finish_child()
		return
	print("MAIN_PERSISTENCE_ISOLATED user_dir=" + user_dir)
	if stage=="create":
		_check(not FileAccess.file_exists("user://save.cfg"), "isolated lifecycle starts without a player save")
		var legacy := SaveStore.default_data()
		legacy.career.runs=6
		_check(SaveStore.new().save_data(legacy),"Create synthetic legacy data only after isolation checks")
	var original_hash := FileAccess.get_sha256("user://save.cfg")
	if failures > 0:
		_finish_child()
		return
	change_scene_to_file("res://scenes/main.tscn")
	for _frame in range(5):
		await process_frame
		if current_scene != null and current_scene.persistence_enabled:
			break
	var main = current_scene
	_check(main != null and main.persistence_enabled, "the real current_scene lifecycle enables persistence")
	if main != null:
		main.set_process(false)
		if stage=="create":
			_check(main.save_slots.active_slot==1 and main.save_data.career.runs==6,"Real current_scene migrates synthetic legacy into slot one")
			_check(main.save_store.save_path=="user://save_slots/slot_1/save.cfg","Production store identity is the actual active slot")
			main.audio_director.music_volume=0.27
			main.save_data.career.runs=11
			_check(main._save_preferences(),"Real lifecycle saves profile one")
			main._show_save_slots()
			main.save_slots_screen.cards[2].load.pressed.emit()
			_check(main.save_slots.active_slot==3 and main.save_data.career.runs==0,"Title management loads independent empty slot three")
			main.audio_director.music_volume=0.62
			main.save_data.career.runs=33
			main.save_slots_screen.cards[2].save.pressed.emit()
			_check(main.save_store.last_save_error==OK and main.save_slots.slot_info(3).data.career.runs==33,"Real UI saves profile three")
		else:
			_check(main.save_slots.active_slot==3 and main.save_store.save_path=="user://save_slots/slot_3/save.cfg","A fresh process remembers the actual current slot")
			_check(main.save_data.career.runs==33 and is_equal_approx(main.audio_director.music_volume,0.62),"A fresh process restores independent profile and preferences")
			_check(main.save_slots.slot_info(1).data.career.runs==11 and is_equal_approx(main.save_slots.slot_info(1).data.settings.music_volume,0.27),"Inactive profile remains independent across process restart")
		_check(FileAccess.get_sha256("user://save.cfg")==original_hash,"Migration and profile operations preserve the original legacy file")
		_check(SaveStore.new().load_data().career.runs==6,"Original legacy progress is never overwritten by active profiles")
		var playbacks := AudioTeardown.capture(main)
		main.audio_director.shutdown()
		main.queue_free()
		await process_frame
		_check(await AudioTeardown.wait_for_release(self, playbacks), "lifecycle teardown drains audio")
	_finish_child()

func _canonical(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("MAIN_PERSISTENCE_FAIL " + message)

func _finish_child() -> void:
	print("MAIN_PERSISTENCE_CHILD_COMPLETE failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func _finish() -> void:
	print("TEST_COMPLETE test_main_persistence_mode.gd")
	quit(0 if failures == 0 else 1)

func _finalize() -> void:
	if owned_pid > 0 and OS.is_process_running(owned_pid):
		OS.kill(owned_pid)
