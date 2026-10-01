extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/save_store.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	await process_frame
	var panel = main.get_node_or_null("CanvasLayer/SettingsScreen/Center/Card/Content/AudioLevels")
	assert(panel != null, "Settings must expose independent music and effects volume controls, not only backend fields")
	if panel == null:
		quit(1)
		return
	var master: HSlider = panel.get_node("Master/Slider")
	var music: HSlider = panel.get_node("Music/Slider")
	var effects: HSlider = panel.get_node("Effects/Slider")
	main._show_settings()
	assert(master.has_focus(), "Opening settings must focus the first editable volume")
	music.value = 35
	assert(is_equal_approx(main.audio_director.music_volume, 0.35), "The music UI must reach the real music bus setting")
	assert(is_equal_approx(main.audio_director.master_volume, 0.65) and is_equal_approx(main.audio_director.effects_volume, 0.65), "Changing music must not change the other channels")
	effects.value = 80
	master.value = 50
	assert(is_equal_approx(main.audio_director.effects_volume, 0.8) and is_equal_approx(main.audio_director.master_volume, 0.5))
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.35)))
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects")), linear_to_db(0.8)))
	music.value = 0
	assert(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) <= -70.0 and main.audio_director.effects_volume == 0.8, "Zero music must silence only Music")
	music.value = 100
	assert(main.audio_director.music_volume == 1.0)
	for language in ["zh", "en"]:
		main._set_language_preference(language)
		assert(panel.get_node("Music/Name").text == ("音乐" if language == "zh" else "MUSIC"))
		assert(panel.get_node("Effects/Name").text == ("音效" if language == "zh" else "EFFECTS"))
		assert(panel.get_node("Music/Value").text == "100%")
		assert("AUTO-SAVED" not in panel.get_node("Hint").text and "自动保存" not in panel.get_node("Hint").text, "Isolated playtests must not promise to save preferences")
	master.grab_focus()
	await _press(KEY_TAB)
	assert(music.has_focus(), "Tab must reach music without leaving the settings panel")
	await _press(KEY_LEFT)
	assert(music.value == 95, "Left/right must adjust the focused channel in five-percent increments")
	await _press(KEY_DOWN)
	assert(effects.has_focus(), "Down must navigate to the next channel, not adjust the old channel")
	await _press(KEY_TAB)
	assert(main.settings_mute_button.has_focus(), "The audio focus chain must continue into existing settings")
	var back: Button = main.get_node("CanvasLayer/SettingsScreen/Center/Card/Content/BackButton")
	back.grab_focus()
	await _press(KEY_TAB)
	assert(master.has_focus(), "Tab must wrap within visible settings controls")
	main._close_submenu()
	assert(main.start_button.has_focus())
	main.run.phase = main.RunState.Phase.PAUSED
	main._show_pause_settings()
	assert(master.has_focus())
	main._close_submenu()
	assert(main.get_node("CanvasLayer/PauseScreen/Center/Card/Content/ResumeButton").has_focus())
	await _legacy_round_trip(main)
	main.queue_free()
	await process_frame
	quit()

func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = key
	root.push_input(event)
	await process_frame

func _legacy_round_trip(main: Node) -> void:
	# Only this uniquely named test file is writable; real user://save.cfg is never loaded.
	var path := "user://test_audio_settings_%s.cfg" % Time.get_ticks_usec()
	var store := SaveStore.new(path)
	var legacy := ConfigFile.new()
	var data := SaveStore.default_data()
	data.settings.music_volume = 0.25
	data.settings.effects_volume = 0.75
	data.career.runs = 9
	legacy.set_value("meta", "version", 5)
	legacy.set_value("scores", "items", [])
	for section in ["settings", "career", "tour"]:
		for key in data[section]:
			legacy.set_value(section, key, data[section][key])
	assert(legacy.save(path) == OK)
	var before := FileAccess.get_file_as_bytes(path)
	main._configure_persistence(store, true)
	assert(main.settings_audio_panel.get_node("Hint").text == main._text("settings.audio.hint"), "Normal settings must identify automatic saving in the active locale")
	assert(FileAccess.get_file_as_bytes(path) == before, "Loading old settings must not rewrite the legacy file")
	var panel = main.get_node("CanvasLayer/SettingsScreen/Center/Card/Content/AudioLevels")
	assert(panel.get_node("Music/Slider").value == 25 and panel.get_node("Effects/Slider").value == 75)
	panel.get_node("Music/Slider").value = 40
	panel.get_node("Effects/Slider").value = 90
	var reloaded = MainScene.instantiate()
	root.add_child(reloaded)
	reloaded.set_process(false)
	reloaded._configure_persistence(SaveStore.new(path), true)
	assert(reloaded.audio_director.music_volume == 0.4 and reloaded.audio_director.effects_volume == 0.9)
	assert(reloaded.save_data.career.runs == 9 and reloaded.save_data.version == SaveStore.CURRENT_VERSION, "Saving changed audio must preserve old progress while upgrading the schema")
	reloaded.queue_free()
	await process_frame
	main.persistence_enabled = false
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
