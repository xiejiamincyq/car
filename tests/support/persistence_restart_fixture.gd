extends SceneTree
## Child-only fixture. It never loads user://save.cfg or attaches a playtest recorder.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/save_store.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["writer", "reader"]:
		quit(2)
		return
	var path := String(args[1])
	var absolute := ProjectSettings.globalize_path(path).simplify_path().replace("\\", "/")
	var tmp_root := ProjectSettings.globalize_path("res://tmp/").simplify_path().replace("\\", "/").trim_suffix("/") + "/"
	if not absolute.begins_with(tmp_root + "persistence-restart-") or not absolute.ends_with("/synthetic-save.cfg"):
		quit(2)
		return
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	_check(not main.persistence_enabled, "Fixture startup must not load the real user save")
	main._configure_persistence(SaveStore.new(path), true)
	if args[0] == "writer":
		_write_result_and_return(main, path)
	else:
		_read_restarted_main(main)
	var pending := AudioTeardown.capture(main.audio_director)
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, pending), "Child audio shutdown must complete")
	if failures == 0:
		print("PERSISTENCE_%s_COMPLETE" % String(args[0]).to_upper())
	quit(0 if failures == 0 else 1)

func _write_result_and_return(main, path: String) -> void:
	_check(main.save_data.career.runs == 9 and main.save_data.top_scores.is_empty(), "Writer must load the synthetic baseline")
	main._set_audio_channel_volume(&"Master", 0.4)
	main._set_audio_channel_volume(&"Music", 0.3)
	main._set_audio_channel_volume(&"Effects", 0.7)
	main._toggle_audio_mute()
	main._cycle_difficulty()
	main._set_language_preference("en")
	main._start_new_run()
	main._process(3.0)
	# Synthetic near-finish state, then the real RunState finish transition and
	# Main settlement path. This is persistence evidence, not a human clear.
	main.run.score = 1499
	main.run.distance = main.run.progression.finish_distance - 1.0
	main.run.elapsed_seconds = 41.0
	main.run.overtakes = 4
	main.run.near_misses = 2
	main.run.tick(1.0, 10.0, main.drive.max_speed)
	main._process(0.0)
	_check(main.run.phase == main.RunState.Phase.RUN_CLEAR and main.result_screen.visible, "Normal settlement must be reached")
	_check(main.save_data.career.runs == 10 and main.save_data.top_scores[0].score == 1500, "Settlement must update career and score once")
	var settled_hash := FileAccess.get_sha256(path)
	main.get_node("CanvasLayer/ResultScreen/Center/Card/Content/TitleButton").pressed.emit()
	_check(main.run.phase == main.RunState.Phase.TITLE and main.title_screen.visible, "Real result button must return to title")
	_check(FileAccess.get_sha256(path) == settled_hash, "Returning to title must not rewrite or erase settlement")

func _read_restarted_main(main) -> void:
	var data: Dictionary = main.save_data
	_check(data.top_scores.size() == 1, "Reader must load exactly one settled result from the previous process")
	if not data.top_scores.is_empty():
		_check(data.top_scores[0].score == 1500 and data.top_scores[0].difficulty == 2, "Score and difficulty must survive process restart")
	_check(data.career.runs == 10 and is_equal_approx(data.career.total_distance, 4450.0), "Career count and distance must survive process restart")
	_check(data.career.overtakes == 4 and data.career.near_misses == 2 and is_equal_approx(data.career.longest_survival, 42.0), "Career detail must survive process restart")
	_check(main.audio_director.muted and main.difficulty_index == 2 and main.language_preference == "en", "Settings must load into a new Main")
	_check(is_equal_approx(main.audio_director.master_volume, 0.4) and is_equal_approx(main.audio_director.music_volume, 0.3) and is_equal_approx(main.audio_director.effects_volume, 0.7), "All three audio settings must survive process restart")
	_check(data.tour.track_results.neon_coast.cleared, "Tour clear must survive process restart")
	_check(main.title_best_scores.text.contains("001500"), "Reopened title must actually render the persisted score")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
