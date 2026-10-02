extends SceneTree
## Memory-only SaveStore double: no formal or synthetic save is opened/written.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/save_store.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")

class MemoryStore extends SaveStore:
	var fixture := SaveStore.default_data()
	var fixture_status: StringName = &"primary"
	var fail_save := true
	var load_calls := 0
	var save_calls := 0
	var last_attempt: Dictionary = {}

	func _init() -> void:
		super("res://tmp/save-feedback-unused.cfg")

	func load_data() -> Dictionary:
		load_calls += 1
		last_load_status = fixture_status
		return fixture.duplicate(true)

	func save_data(data: Dictionary) -> bool:
		save_calls += 1
		last_attempt = data.duplicate(true)
		last_save_error = ERR_CANT_CREATE if fail_save else OK
		return not fail_save

var failures := 0
var notice_samples: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for locale in ["zh", "en"]:
		await _load_feedback(locale)
		await _save_feedback(locale)
		await _disabled_feedback(locale)
		await _nonblocking_feedback(locale)
	print("SAVE_FEEDBACK_CHECKS_COMPLETE failures=%d" % failures)
	print("TEST_COMPLETE test_save_feedback.gd")
	quit(0 if failures == 0 else 1)

func _new_main():
	var main = MainScene.instantiate()
	# Not current_scene: _ready() must not enable the real user://save.cfg store.
	root.add_child(main)
	main.set_process(false)
	_check(not main.persistence_enabled, "isolated Main starts with persistence disabled")
	return main

func _fixture(locale: String, status: StringName = &"primary") -> MemoryStore:
	var store := MemoryStore.new()
	store.fixture_status = status
	store.fixture.settings.language = locale
	store.fixture.career.runs = 4
	return store

func _load_feedback(locale: String) -> void:
	for status in [&"primary", &"missing", &"backup", &"invalid", &"io_error"]:
		var main = _new_main()
		var store := _fixture(locale, status)
		main._configure_persistence(store, true)
		_check(store.load_calls == 1 and store.save_calls == 0, "configure loads once without repair writes: %s/%s" % [locale, status])
		_check(main.save_data == store.fixture, "configure preserves the complete in-memory fixture")
		if status == &"backup":
			_expect_notice(main, "persistence.recovered", locale)
		elif status in [&"invalid", &"io_error"]:
			_expect_notice(main, "persistence.load_blocked", locale)
			_expect_failed_hint(main, locale)
		else:
			_expect_clear(main, "fresh and primary loads must not warn")
		await _dispose(main)

func _save_feedback(locale: String) -> void:
	var main = _new_main()
	var store := _fixture(locale)
	main._configure_persistence(store, true)
	_check(main.has_method("_write_save_data"), "Main must centralize save-result handling")
	main._show_settings()
	main.audio_director.music_volume = 0.21
	main._save_preferences()
	_check(store.save_calls == 1, "preferences attempt exactly one save without retry")
	_check(main.save_data.settings.music_volume == 0.21 and store.last_attempt.settings.music_volume == 0.21, "failed preferences retain the new value in memory")
	_expect_notice(main, "persistence.save_failed", locale)
	_expect_failed_hint(main, locale)
	var notice = _notice(main)
	var notice_id: int = notice.get_instance_id() if notice != null else 0
	var first_text: String = notice.text if notice != null else ""
	main._save_preferences()
	_check(store.save_calls == 2, "another explicit preferences action saves once, not a retry loop")
	notice = _notice(main)
	_check(notice != null and notice.get_instance_id() == notice_id and notice.text == first_text, "repeated failures reuse one unchanged notice")

	main.save_data.tour.selected_vehicle_id = &"driftwing"
	main._save_tour_selection()
	_check(store.save_calls == 3, "tour selection attempts exactly one save")
	_check(main.save_data.tour.selected_vehicle_id == &"driftwing" and store.last_attempt.tour.selected_vehicle_id == &"driftwing", "failed tour save retains the selection in memory")
	_expect_notice(main, "persistence.save_failed", locale)
	_expect_failed_hint(main, locale)

	main._close_submenu()
	main.run.phase = main.RunState.Phase.GAME_OVER
	main.run.score = 1500
	main.run.distance = 845.0
	main.run.elapsed_seconds = 42.0
	main._persist_result_once()
	_check(store.save_calls == 4, "settlement attempts exactly one save")
	_check(main.result_persisted and main.save_data.career.runs == 5 and main.save_data.top_scores[0].score == 1500, "failed settlement retains the result and marks it processed")
	_expect_notice(main, "persistence.save_failed", locale)
	_expect_failed_hint(main, locale)
	var settled: Dictionary = main.save_data.duplicate(true)
	main._persist_result_once()
	main._update_hud()
	main._update_hud()
	_check(store.save_calls == 4 and main.save_data == settled, "HUD refresh and repeated settlement do not retry or double-count a failed result")

	store.fail_save = false
	main._save_preferences()
	_check(store.save_calls == 5 and main.save_data.career.runs == 5, "a later successful action saves the retained career once")
	_expect_clear(main, "later successful saving clears the failure notice")
	_check(main.settings_audio_panel.get_node("Hint").text == main._text("settings.audio.hint"), "successful saving restores the normal localized saving hint")
	main._persist_result_once()
	_check(store.save_calls == 5 and main.save_data.career.runs == 5, "successful later save still does not re-settle the result")
	await _dispose(main)

func _disabled_feedback(locale: String) -> void:
	var main = _new_main()
	var store := _fixture(locale, &"io_error")
	main._configure_persistence(store, false)
	main.language = locale
	main.language_preference = locale
	main._apply_localized_texts()
	main._save_preferences()
	main._save_tour_selection()
	main.run.phase = main.RunState.Phase.GAME_OVER
	main._persist_result_once()
	_check(store.load_calls == 0 and store.save_calls == 0, "disabled persistence performs no load or save calls")
	_check(main.result_persisted and main.save_data.career.runs == 1, "disabled persistence still permits normal in-memory settlement")
	_expect_clear(main, "disabled persistence creates no save-failure notice")
	var hint: String = main.settings_audio_panel.get_node("Hint").text
	_check(not hint.contains("AUTO-SAVED") and not hint.contains("自动保存"), "disabled persistence never promises saving")
	await _dispose(main)

func _nonblocking_feedback(locale: String) -> void:
	var main = _new_main()
	var store := _fixture(locale)
	main._configure_persistence(store, true)
	main._show_settings()
	var focused: Control = root.gui_get_focus_owner()
	_check(not main._write_save_data(), "failed unified writer reports false")
	var notice := _notice(main)
	_check(notice != null and notice.focus_mode == Control.FOCUS_NONE and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE, "save feedback cannot capture keyboard or pointer input")
	_check(root.gui_get_focus_owner() == focused, "save failure does not steal the settings focus")
	var original_text: String = notice.text if notice != null else ""
	var other_locale := "en" if locale == "zh" else "zh"
	main._set_language_preference(other_locale)
	_expect_notice(main, "persistence.save_failed", other_locale)
	_expect_failed_hint(main, other_locale)
	_check(notice != null and notice.text != original_text and root.gui_get_focus_owner() == focused, "language changes refresh the existing failure notice without moving focus")
	_check(store.save_calls == 2, "language change makes one normal save attempt without retry")
	main._close_submenu()
	main._reset_run(174)
	main.run.phase = main.RunState.Phase.RUNNING
	main.drive.speed = 90.0
	var elapsed: float = main.run.elapsed_seconds
	var distance: float = main.run.distance
	_check(not main._write_save_data(), "failure during driving still reports false")
	main._process(0.05)
	_check(main.run.phase == main.RunState.Phase.RUNNING and main.run.elapsed_seconds > elapsed and main.run.distance > distance, "failed saving neither pauses nor blocks a real driving frame")
	_check(not main.confirmation_screen.visible and not main.settings_screen.visible and store.save_calls == 3, "driving feedback creates no modal screen or implicit retries")
	await _dispose(main)

func _notice(main: Node) -> Label:
	for property in main.get_property_list():
		if property.name == "persistence_notice":
			return main.get("persistence_notice") as Label
	return null

func _notice_key(main: Node) -> String:
	for property in main.get_property_list():
		if property.name == "persistence_notice_key":
			return String(main.get("persistence_notice_key"))
	return ""

func _expect_notice(main: Node, key: String, locale: String) -> void:
	var notice := _notice(main)
	_check(notice != null, "Main exposes a persistence notice Label")
	_check(_notice_key(main) == key, "notice identifies the correct persistence state: " + key)
	if notice == null:
		return
	_check(notice.visible and not notice.text.is_empty(), "persistence warning is visible and nonempty")
	_check(notice.text == main._text(key) and notice.text != key, "notice is translated in " + locale)
	if locale == "zh":
		notice_samples[key] = notice.text
	elif notice_samples.has(key):
		_check(notice.text != notice_samples[key], "Chinese and English persistence notices differ")

func _expect_failed_hint(main: Node, locale: String) -> void:
	var hint: String = main.settings_audio_panel.get_node("Hint").text
	_check(hint == main._text("settings.audio.failed_hint") and hint != "settings.audio.failed_hint", "failed saving uses its localized honest settings hint: " + locale)
	_check(not hint.contains("AUTO-SAVED") and not hint.contains("自动保存"), "failure feedback never claims preferences were saved")

func _expect_clear(main: Node, message: String) -> void:
	var notice := _notice(main)
	_check(notice != null and not notice.visible and _notice_key(main).is_empty(), message)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("SAVE_FEEDBACK_FAIL " + message)

func _dispose(main: Node) -> void:
	var playbacks := AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, playbacks), "test teardown releases real audio playbacks within its deadline")
