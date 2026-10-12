extends SceneTree
## Real menu signals with memory-only storage; no player files or invented runs.
const MainScene = preload("res://scenes/main.tscn")
const Store = preload("res://scripts/save_store.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
class MemoryStore extends Store:
	var writes: Array[Dictionary] = []
	var fail := false
	func load_data() -> Dictionary:
		return Store.default_data()
	func save_data(data: Dictionary) -> bool:
		writes.append(data.duplicate(true))
		return not fail
var failures: Array[String] = []
var checks := 0
func _init() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	var title: Node = main.title_screen.get_node("Center/Card/Content")
	var pause: Node = main.pause_screen.get_node("Center/Card/Content")
	var panel: Control = main.get_node_or_null("CanvasLayer/LeaderboardScreen")
	_check((title.find_child("LeaderboardButton",true,false) != null), "Title has a leaderboard action")
	_check((title.find_child("SaveButton",true,false) != null) and pause.has_node("SaveButton"), "Title and pause offer explicit saving")
	_check(panel != null, "Leaderboard is an independent menu, not always-visible title text")
	if panel != null and (title.find_child("LeaderboardButton",true,false) != null) and (title.find_child("SaveButton",true,false) != null) and pause.has_node("SaveButton"):
		var store := MemoryStore.new()
		main._configure_persistence(store, true)
		for locale in ["zh", "en"]:
			main._set_language_preference(locale)
			main.save_data.top_scores = []
			main._update_scoreboards()
			title.find_child("LeaderboardButton",true,false).pressed.emit()
			main._process(0.01)
			_check(panel.visible and not main.title_screen.visible and main._capture_screen_name() == "leaderboard", "Leaderboard opens through its button")
			_check(main.title_best_scores.is_visible_in_tree() and main.title_best_scores.text == main._format_top_scores([]), "Empty board has localized truthful feedback")
			panel.get_node("Center/Card/Content/BackButton").pressed.emit()
			_check(main.title_screen.visible and title.find_child("LeaderboardButton",true,false).has_focus(), "Back restores leaderboard button focus")
			main.save_data.top_scores = [{"score":999999,"difficulty":2,"distance":3999.0}]
			title.find_child("LeaderboardButton",true,false).pressed.emit()
			_check(main.title_best_scores.text.contains("999999"), "Board reads all actual current score records")
			main._close_submenu()
			_check(not panel.visible and main.title_screen.visible, "Cancel uses the same close path")
			var career: Dictionary = main.save_data.career.duplicate(true)
			var before := store.writes.size()
			title.find_child("SaveButton",true,false).pressed.emit()
			_check(store.writes.size() == before+1 and store.writes[-1].settings.language == locale, "One press writes current preferences once")
			_check(main.persistence_notice_key == "persistence.saved" and main.persistence_notice.visible, "Successful storage produces localized success notice")
			_check(main.persistence_notice.text == main._text("persistence.saved") and main.save_data.career == career, "Saving does not record a run or award progression")
			main._process(2.6)
			_check(not main.persistence_notice.visible and main.persistence_notice_key.is_empty(), "Ordinary save success expires without changing the race")
			store.fail = true
			title.find_child("SaveButton",true,false).pressed.emit()
			_check(main.persistence_notice_key == "persistence.save_failed", "Failed saving never reports success")
			store.fail = false
		main._start_new_run()
		main._process(3.0)
		main._pause_run()
		var elapsed: float = main.run.elapsed_seconds
		var distance: float = main.run.distance
		pause.get_node("SaveButton").pressed.emit()
		_check(main.run.phase == main.RunState.Phase.PAUSED and main.run.elapsed_seconds == elapsed and main.run.distance == distance, "Pause save never resumes or mutates the race")
		main._configure_persistence(store, false)
		_check(title.find_child("SaveButton",true,false).disabled and pause.get_node("SaveButton").disabled, "Session-only persistence cannot offer a false save")
		var count := store.writes.size()
		main._save_now()
		_check(store.writes.size() == count and main.persistence_notice_key != "persistence.saved", "Disabled mode writes nothing and cannot claim success")
	var playbacks := AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, playbacks), "Audio teardown completes")
	for failure in failures: push_error("MENU_ACTIONS "+failure)
	print("MENU_ACTIONS_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	print("TEST_COMPLETE test_product_menu_actions.gd")
	quit(0 if failures.is_empty() else 1)
