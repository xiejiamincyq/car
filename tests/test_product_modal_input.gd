extends SceneTree
## Real engine key dispatch against Main; persistence is memory-only.
const MainScene = preload("res://scenes/main.tscn")
const Store = preload("res://scripts/save_store.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")

class MemoryStore extends Store:
	func load_data() -> Dictionary: return Store.default_data()
	func save_data(_data: Dictionary) -> bool: return true

var failures: Array[String] = []
var checks := 0
var main

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _button(screen: Control, node_name: String) -> Button:
	return screen.find_child(node_name, true, false) as Button

func _snapshot() -> Dictionary:
	return {"distance":main.run.distance, "fuel":main.run.fuel,
		"elapsed":main.run.elapsed_seconds, "countdown":main.run.countdown_remaining}

func _check_frozen(before: Dictionary, context: String) -> void:
	main._process(0.25)
	_check(main.run.phase == main.RunState.Phase.PAUSED, context + ": race stays paused")
	_check(_snapshot() == before, context + ": distance/fuel/time/countdown remain frozen")

func _key(code: Key, action: String = "") -> void:
	# Allow the engine to reset its just-pressed flags, then explicitly step Main
	# once while the real event is current. Main's automatic process is disabled.
	await process_frame
	await process_frame
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	if not action.is_empty():
		_check(Input.is_action_just_pressed(action), "Real key maps to " + action)
	main._process(0.01)
	var release := InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame
	await process_frame

func _fresh_paused() -> void:
	main._return_to_title()
	main._start_new_run()
	main._process(3.0)
	_check(main.run.phase == main.RunState.Phase.RUNNING, "Fixture begins a real running race")
	main._pause_run()
	_check(main.run.phase == main.RunState.Phase.PAUSED, "Fixture pauses before opening modal")

func _run() -> void:
	main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main._configure_persistence(MemoryStore.new(), true)
	main.set_process(false)
	await process_frame
	for locale in ["zh", "en"]:
		main._set_language_preference(locale)
		for entry_name in ["SettingsButton", "ControlsButton"]:
			main._return_to_title()
			var entry := _button(main.title_screen, entry_name)
			entry.grab_focus()
			entry.pressed.emit()
			await _key(KEY_ESCAPE, "ui_cancel")
			_check(main.title_screen.visible and not main.settings_screen.visible and not main.controls_screen.visible,
				locale + " title submenu Escape returns to title")
			_check(entry.has_focus(), locale + " title submenu restores original " + entry_name + " focus")

		_fresh_paused()
		var pause_settings := _button(main.pause_screen, "SettingsButton")
		pause_settings.grab_focus()
		pause_settings.pressed.emit()
		var settings_before := _snapshot()
		await _key(KEY_ESCAPE, "ui_cancel")
		_check(main.pause_screen.visible and pause_settings.has_focus(),
			locale + " paused settings Escape restores its SettingsButton entry")
		_check_frozen(settings_before, locale + " paused settings Escape")

		# Fresh fixtures isolate each key, so a leak in one cannot hide another.
		for modal in ["settings", "confirmation"]:
			for code in [KEY_SPACE, KEY_R, KEY_ENTER]:
				_fresh_paused()
				if modal == "settings":
					_button(main.pause_screen, "SettingsButton").pressed.emit()
				else:
					_button(main.pause_screen, "RestartButton").pressed.emit()
				var before := _snapshot()
				var action := "pause_game" if code == KEY_SPACE else ("restart_run" if code == KEY_R else "ui_accept")
				await _key(code, action)
				var context := "%s %s key %d" % [locale, modal, code]
				_check_frozen(before, context)
				if modal == "settings" and code == KEY_R:
					_check(main.settings_screen.visible and not main.confirmation_screen.visible,
						context + ": restart cannot replace settings with a confirmation")
				if code != KEY_ENTER:
					await _key(KEY_ESCAPE, "ui_cancel")
					_check(main.pause_screen.visible and not main.settings_screen.visible and not main.confirmation_screen.visible,
						context + ": Escape returns to pause without losing race")
					_check_frozen(before, context + " after Escape")

		# Outside a modal, the same real Space binding must still work normally.
		main._return_to_title()
		main._start_new_run()
		main._process(3.0)
		await _key(KEY_SPACE, "pause_game")
		_check(main.pause_screen.visible and main.run.phase == main.RunState.Phase.PAUSED,
			locale + " unobstructed Space pauses running race")
		var before := _snapshot()
		await _key(KEY_SPACE, "pause_game")
		_check(not main.pause_screen.visible and main.run.phase == main.RunState.Phase.COUNTDOWN,
			locale + " unobstructed Space resumes through countdown")
		_check(main.run.distance == before.distance and main.run.fuel == before.fuel and main.run.elapsed_seconds == before.elapsed,
			locale + " resume countdown does not immediately advance race")
		main._process(3.0)
		_check(main.run.phase == main.RunState.Phase.RUNNING, locale + " resume countdown completes normally")

	var playbacks := AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, playbacks), "Audio teardown completes")
	for failure in failures: push_error("MODAL_INPUT " + failure)
	print("MODAL_INPUT_RESULT ", JSON.stringify({"checks":checks,"failures":failures,
		"scope":"real Main, engine key events, zh/en, memory-only save; no desktop input"}))
	print("TEST_COMPLETE test_product_modal_input.gd")
	quit(0 if failures.is_empty() else 1)
