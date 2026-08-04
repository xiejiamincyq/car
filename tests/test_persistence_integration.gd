extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/save_store.gd")

var test_path := "user://test_progression_integration.cfg"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var first = MainScene.instantiate()
	root.add_child(first)
	first._configure_persistence(SaveStore.new(test_path), true)
	assert(first.get_node("CanvasLayer/TitleScreen/Center/Card/Content/BestScores").text.contains("暂无成绩"), "A fresh profile must explain that no scores exist")

	first.audio_volume = 0.4
	first.audio_muted = true
	first.difficulty_index = 2
	first._save_preferences()
	first._start_new_run()
	first.run.tick(3.0, 0.0, first.GameConfig.MAX_SPEED)
	first.run.score = 1500
	first.run.distance = 845.0
	first.run.elapsed_seconds = 42.0
	first.run.overtakes = 4
	first.run.near_misses = 2
	first.run.difficulty_stage = 2
	first.run.end()
	first._update_hud()
	assert(first.get_node("CanvasLayer/ResultScreen/Center/Card/Content/NewRecord").visible, "A first-place result must show NEW RECORD")
	var result_screen: Control = first.get_node("CanvasLayer/ResultScreen")
	var result_card: Control = first.get_node("CanvasLayer/ResultScreen/Center/Card")
	assert(result_screen.get_global_rect().encloses(result_card.get_global_rect()), "The leaderboard result card must fit inside the 720p viewport")
	var stored := SaveStore.new(test_path).load_data()
	assert(stored.top_scores[0].score == 1500 and stored.career.runs == 1, "Settlement must persist leaderboard and career data")
	await _free_main(first)

	var reopened = MainScene.instantiate()
	root.add_child(reopened)
	reopened._configure_persistence(SaveStore.new(test_path), true)
	assert(reopened.audio_muted and is_equal_approx(reopened.audio_volume, 0.4) and reopened.difficulty_index == 2, "Audio and difficulty settings must survive a process-equivalent reload")
	var best_scores: Label = reopened.get_node("CanvasLayer/TitleScreen/Center/Card/Content/BestScores")
	assert(best_scores.text.contains("001500") and best_scores.text.contains("困难"), "The title must show persisted score and difficulty")
	assert(reopened.save_data.career.total_distance == 845.0 and reopened.save_data.career.overtakes == 4, "Career totals must reload unchanged")
	await _free_main(reopened)
	_cleanup()
	quit()

func _free_main(main: Node) -> void:
	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	await process_frame

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = test_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
