extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.get_node("CanvasLayer/SettingsScreen/Center/Card/Content/HighContrastButton") is Button, "Settings must expose a high-contrast toggle")
	assert(main.get_node("CanvasLayer/SettingsScreen/Center/Card/Content/ReducedFlashingButton") is Button, "Settings must expose a reduced-flashing toggle")
	assert(main.get_node("CanvasLayer/SettingsScreen/Center/Card/Content/ScreenShakeButton") is Button, "Settings must expose a screen-shake toggle")
	main._toggle_high_contrast()
	assert(main.high_contrast_enabled and main.save_data.settings.high_contrast, "High contrast must apply immediately and update persisted settings")
	main._toggle_reduced_flashing()
	assert(main.reduced_flashing_enabled and not main.feedback.flashing_enabled and main.save_data.settings.reduced_flashing, "Reduced flashing must disable warning flashes and persist")
	main.screen_shake = Vector2(8.0, -5.0)
	main._toggle_screen_shake()
	assert(not main.screen_shake_enabled and main.screen_shake == Vector2.ZERO and not main.save_data.settings.screen_shake, "Disabling screen shake must stop active movement and persist")
	main.audio_director.stop_run_audio()
	for player in [main.audio_director.collision_audio, main.audio_director.engine_audio, main.audio_director.acceleration_audio, main.audio_director.pickup_audio, main.audio_director.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	quit()
