extends SceneTree

const Recorder = preload("res://tests/playtest_session_recorder.gd")

func _init() -> void:
	var recorder = Recorder.new()
	var sample := {"seed": 611, "track": "neon_coast", "vehicle": "pulse_gt", "difficulty": 1,
		"phase": "running", "seconds": 12.0, "distance": 800.0, "fuel": 83.0,
		"integrity": 92.0, "score": 1200, "coins": 7, "collisions": 1, "overtakes": 4,
		"failure_reason": ""}
	assert(recorder.observe(sample).is_empty())
	sample.phase = "paused"
	assert(recorder.observe(sample).is_empty(), "Pause is not a result")
	sample.phase = "clear"
	var result: Dictionary = recorder.observe(sample)
	assert(result.outcome == "clear" and result.coins == 7 and result.integrity == 92)
	assert(result.source == "interactive_unverified", "Recorded results do not imply human acceptance")
	assert(recorder.observe(sample).is_empty(), "Result screens must not record every frame")
	sample.phase = "countdown"
	sample.seconds = 0.0
	assert(recorder.observe(sample).is_empty())
	sample.phase = "running"
	sample.seconds = 5.0
	recorder.observe(sample)
	sample.seed = 612
	sample.seconds = 0.0
	sample.phase = "countdown"
	result = recorder.observe(sample)
	assert(result.outcome == "aborted" and result.seed == 611 and result.seconds == 5.0)
	sample.phase = "failed"
	sample.failure_reason = "integrity"
	result = recorder.observe(sample)
	assert(result.outcome == "failed" and result.failure_reason == "integrity")
	assert(recorder.finish().is_empty(), "Closing a completed result must not duplicate it")
	sample.seed = 613
	sample.phase = "running"
	recorder.observe(sample)
	assert(recorder.finish().outcome == "aborted", "Window close must retain an unfinished attempt separately")
	var path := "user://test-playtest-record-%d.jsonl" % Time.get_ticks_usec()
	assert(recorder.append_result(path,result) == OK)
	assert(recorder.append_result(path,result) == OK)
	var file := FileAccess.open(path,FileAccess.READ)
	assert(JSON.parse_string(file.get_line()).failure_reason == "integrity")
	assert(JSON.parse_string(file.get_line()).seed == 612, "Appending must preserve prior rows")
	file.close()
	DirAccess.remove_absolute(path)
	recorder.free()
	print("TEST_COMPLETE test_playtest_recorder.gd")
	quit()
