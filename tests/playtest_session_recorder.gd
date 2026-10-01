extends Node
## Opt-in, local-only observer attached by PlaytestLauncher, never by normal play.
const Run = preload("res://scripts/run_state.gd")
var source_main
var output_path := ""
var source_label := "interactive_unverified"
var _last: Dictionary = {}
var _finished := false
var _write_failed := false

func _ready() -> void:
	if is_instance_valid(source_main):
		source_main.run_resetting.connect(_before_run_reset)

func _before_run_reset() -> void:
	# Preserve the terminal state before a result-screen action erases it,
	# even when the action occurs before this observer's next frame.
	_store(observe(_snapshot()))
	_store(finish())

func _process(_delta: float) -> void:
	if is_instance_valid(source_main):
		_store(observe(_snapshot()))

func _exit_tree() -> void:
	if is_instance_valid(source_main):
		_store(observe(_snapshot()))
	_store(finish())

func observe(sample: Dictionary) -> Dictionary:
	if sample.phase == "title":
		return finish()
	var result: Dictionary = {}
	var reset: bool = not _last.is_empty() and (
		sample.seed != _last.seed or sample.track != _last.track or sample.vehicle != _last.vehicle
		or sample.difficulty != _last.difficulty or sample.seconds < _last.seconds
		or (_finished and sample.phase in ["countdown", "running"]))
	if reset:
		result = finish()
		_last = {}
		_finished = false
	_last = sample.duplicate(true)
	if not _finished and sample.phase in ["clear", "failed"]:
		_finished = true
		return _result(sample.phase)
	return result

func finish() -> Dictionary:
	if _last.is_empty() or _finished:
		return {}
	_finished = true
	return _result("aborted")

func _result(outcome: String) -> Dictionary:
	var result := _last.duplicate(true)
	result.erase("phase")
	result["outcome"] = outcome
	result["source"] = source_label
	result["recorded_at_utc"] = Time.get_datetime_string_from_system(true)
	result["version"] = ProjectSettings.get_setting("application/config/version", "dev")
	return result

static func append_result(path: String, result: Dictionary) -> Error:
	var file := FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.seek_end()
	file.store_line(JSON.stringify(result))
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func _store(result: Dictionary) -> void:
	if result.is_empty() or output_path.is_empty() or _write_failed:
		return
	var error := append_result(output_path,result)
	if error != OK:
		_write_failed = true
		push_warning("Playtest recording failed (%d); driving continues, no results will be claimed saved." % error)
	else:
		print("PLAYTEST_RESULT ", JSON.stringify(result))

func _snapshot() -> Dictionary:
	var run = source_main.run
	var phases := {Run.Phase.TITLE: "title", Run.Phase.COUNTDOWN: "countdown", Run.Phase.RUNNING: "running",
		Run.Phase.PAUSED: "paused", Run.Phase.GAME_OVER: "failed", Run.Phase.RUN_CLEAR: "clear"}
	return {"seed": source_main.current_run_seed, "track": str(source_main.current_track.id),
		"vehicle": str(source_main.current_vehicle.id), "difficulty": source_main.difficulty_index,
		"phase": phases.get(run.phase,"title"), "seconds": run.elapsed_seconds, "distance": run.distance,
		"fuel": run.fuel, "integrity": source_main.integrity.current, "score": run.score,
		"coins": run.coins, "collisions": run.collisions, "overtakes": run.overtakes,
		"failure_reason": str(run.failure_reason)}
