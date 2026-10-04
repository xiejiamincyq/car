extends SceneTree

class FailingCapture extends "res://scripts/runtime_performance_capture.gd":
	var writes := 0
	func _store_line(content: String) -> Error:
		writes += 1
		if writes > 1:
			return ERR_FILE_CANT_WRITE
		_file.store_line(content)
		_file.flush()
		return _file.get_error()

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://scripts/runtime_performance_capture.gd"
	if not ResourceLoader.exists(path):
		_check(false, "passive runtime capture implementation is required")
		_finish()
		return
	var capture_script = load(path)
	var directory := "res://tmp/performance-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var disabled = capture_script.new(directory + "/disabled")
	_check(not disabled.start(false), "disabled capture does not start")
	disabled.poll({"phase": "title"})
	disabled.close()
	_check(not DirAccess.dir_exists_absolute(directory + "/disabled"), "default off creates no directory or file")
	var capture = capture_script.new(directory + "/enabled")
	_check(capture.start(true), "explicit capture starts")
	var context := {"phase": "title", "run_number": 0, "track": "neon_coast", "speed": 0.0, "private_payload": "must-not-log"}
	var before := context.duplicate(true)
	var started: int = capture.started_usec
	capture.poll(context, started)
	_check(context == before, "poll leaves the whole caller dictionary unchanged")
	_check(not capture.start(true), "another start cannot truncate existing evidence")
	capture.poll(context, started + 999999)
	_check(capture.sample_count == 1, "one sample per wall-clock second")
	capture.poll(context, started + 1000000)
	capture.poll(context, started + 12000000)
	_check(capture.sample_count == 3, "long gaps do not create catch-up bursts")
	context.phase = "paused"
	capture.poll(context, started + 12000001)
	_check(capture.sample_count == 4, "phase change is captured before periodic deadline")
	context.run_number = 1
	capture.poll(context, started + 12000002)
	_check(capture.sample_count == 5, "new run is captured immediately")
	capture.poll(context, started + 11000000)
	_check(capture.sample_count == 5, "a reversed clock cannot append misleading samples")
	capture.close()
	_check(not capture.active, "close stops capture")
	capture.poll(context, started + 14000000)
	_check(capture.sample_count == 5, "closed capture cannot append")
	var lines := FileAccess.get_file_as_string(capture.output_path).strip_edges().split("\n")
	_check(lines.size() == 7, "start, five samples and close are flushed as JSONL")
	var first = JSON.parse_string(lines[0])
	var sample = JSON.parse_string(lines[1])
	var last = JSON.parse_string(lines[-1])
	_check(first.event == "capture_started" and last.event == "capture_closed", "terminal lifecycle is explicit")
	_check(last.elapsed_usec >= JSON.parse_string(lines[-2]).elapsed_usec, "terminal timestamp never precedes the last sample")
	_check(first.schema == 1 and sample.schema == 1 and last.schema == 1, "schema is present on every event type")
	_check(sample.phase == "title" and sample.track == "neon_coast", "white-listed context survives")
	_check(not sample.has("private_payload"), "unlisted data cannot leak into telemetry")
	_check(sample.pid == OS.get_process_id() and sample.session == first.session and last.session == first.session, "all rows have the same process/session identity")
	_check(sample.objects > 0 and sample.nodes > 0 and sample.resources > 0, "real engine monitor counts are recorded")
	_check(before.private_payload == context.private_payload and before.track == context.track and before.speed == context.speed, "poll never modifies caller fields")
	var release_metrics: Dictionary = capture.monitor_values(false)
	_check(release_metrics.static_memory_bytes == null and release_metrics.orphan_nodes == null, "release-only unavailable values are null, not zero evidence")
	var blocker_path := directory + "/blocked"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("owned test fixture")
	blocker.close()
	var invalid = capture_script.new(blocker_path + "/capture")
	_check(not invalid.start(true) and not invalid.active, "unwritable location disables capture without throwing")
	invalid.poll(context)
	_check(invalid.sample_count == 0, "failed start does not retry or emit samples")
	var failing := FailingCapture.new(directory + "/write-failure")
	_check(failing.start(true), "IO fault fixture starts with a real header")
	failing.poll(context)
	_check(not failing.active and failing.last_error == ERR_FILE_CANT_WRITE and failing.sample_count == 0, "mid-stream IO failure disables capture and retains error")
	failing.poll(context)
	failing.close()
	_check(failing.writes == 2, "failed IO is not retried and cannot forge a successful terminal row")
	print("PERFORMANCE_CAPTURE_EVIDENCE " + directory)
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("PERFORMANCE_CAPTURE_FAIL " + message)

func _finish() -> void:
	print("PERFORMANCE_CAPTURE_CHECKS_COMPLETE failures=%d" % failures)
	print("TEST_COMPLETE test_runtime_performance_capture.gd")
	quit(0 if failures == 0 else 1)
