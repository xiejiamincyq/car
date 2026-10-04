extends RefCounted
## Opt-in local evidence, not gameplay state or a frame-time benchmark.

const CONTEXT_KEYS := ["phase", "run_number", "track", "vehicle", "difficulty", "speed", "distance", "construction", "overdrive", "window_width", "window_height", "focused"]
const INTERVAL_USEC := 1000000

var active := false
var sample_count := 0
var started_usec := 0
var output_path := ""
var last_error: Error = OK
var _directory: String
var _file: FileAccess
var _session := ""
var _start_attempted := false
var _next_sample_usec := 0
var _last_sample_usec := -1
var _last_state: Array = []

func _init(directory: String = "user://performance") -> void:
	_directory = directory

func start(enabled: bool) -> bool:
	if _start_attempted:
		return false
	_start_attempted = true
	if not enabled:
		return false
	last_error = DirAccess.make_dir_recursive_absolute(_directory)
	if last_error != OK:
		return false
	started_usec = Time.get_ticks_usec()
	_session = "%d-%d" % [OS.get_process_id(), started_usec]
	output_path = _directory.path_join("capture-%s.jsonl" % _session)
	# Never truncate an earlier evidence file, even on an unlikely ID collision.
	if FileAccess.file_exists(output_path):
		last_error = ERR_ALREADY_EXISTS
		return false
	_file = FileAccess.open(output_path, FileAccess.WRITE)
	if _file == null:
		last_error = FileAccess.get_open_error()
		return false
	active = true
	_next_sample_usec = started_usec
	return _write_row({"event": "capture_started", "engine": Engine.get_version_info().string, "debug_build": OS.is_debug_build()}, started_usec)

func poll(context: Dictionary, now_usec: int = -1) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec() if now_usec < 0 else now_usec
	if now < started_usec or now < _last_sample_usec:
		return
	var state := [context.get("phase"), context.get("run_number"), context.get("track")]
	if now < _next_sample_usec and state == _last_state:
		return
	var row := {"event": "sample"}
	for key in CONTEXT_KEYS:
		if context.has(key):
			row[key] = context[key]
	row.merge(monitor_values())
	if _write_row(row, now):
		sample_count += 1
		_last_state = state
		_last_sample_usec = now
		# Wall time, not simulated race time; no catch-up IO after a long frame.
		_next_sample_usec = now + INTERVAL_USEC

func close() -> void:
	if active:
		_write_row({"event": "capture_closed", "samples": sample_count}, maxi(Time.get_ticks_usec(), _last_sample_usec))
	active = false
	if _file != null:
		_file.close()
		_file = null

func monitor_values(debug_build: bool = OS.is_debug_build()) -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_seconds": Performance.get_monitor(Performance.TIME_PROCESS),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC) if debug_build else null,
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) if debug_build else null,
	}

func _write_row(row: Dictionary, now_usec: int) -> bool:
	row.merge({"schema": 1, "session": _session, "pid": OS.get_process_id(), "elapsed_usec": maxi(0, now_usec - started_usec)})
	last_error = _store_line(JSON.stringify(row))
	if last_error != OK:
		active = false
		_file.close()
		_file = null
		return false
	return true

func _store_line(content: String) -> Error:
	_file.store_line(content)
	_file.flush()
	return _file.get_error()
