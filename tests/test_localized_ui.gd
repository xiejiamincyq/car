extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var language_button: Button = main.get_node("CanvasLayer/SettingsScreen/Center/Card/Content/LanguageButton")
	main._set_language_preference("en")
	assert(main.save_data.settings.language == "en", "Changing language must update the persisted settings model")
	assert(main.get_node("CanvasLayer/TitleScreen/Center/Card/Content/StartButton").text == "START RACE", "Title actions must refresh in English")
	assert(language_button.text == "LANGUAGE: ENGLISH", "Settings must expose the active language")
	assert(main.get_node("CanvasLayer/ControlsScreen/Center/Card/Content/Heading").text == "KEYBOARD CONTROLS", "The controls screen must refresh in English")
	assert(main.controls_hint_label.text.contains("SPACE PAUSE"), "Dynamic HUD text must refresh in English")
	main._set_language_preference("zh")
	assert(main.get_node("CanvasLayer/TitleScreen/Center/Card/Content/StartButton").text == "开始比赛", "Title actions must refresh in Chinese")
	assert(language_button.text == "语言：中文", "Settings must expose Chinese as the active language")
	main.audio_director.stop_run_audio()
	for player in [main.audio_director.collision_audio, main.audio_director.engine_audio, main.audio_director.acceleration_audio, main.audio_director.pickup_audio, main.audio_director.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	quit()
