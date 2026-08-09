extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SoundEffects = preload("res://scripts/sound_effects.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(AudioServer.get_bus_index("Master") >= 0, "The Master audio bus must exist")
	assert(AudioServer.get_bus_index("Effects") >= 0, "Gameplay and UI effects need a dedicated bus")
	assert(AudioServer.get_bus_index("Music") >= 0, "A reserved Music bus must exist for later versions")
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio, main.ui_audio, main.event_audio]:
		assert(player.bus == &"Effects", "Every current gameplay player must route through Effects")
	main.audio_volume = 0.25
	main.audio_muted = false
	main._apply_master_audio_settings()
	var master_index := AudioServer.get_bus_index("Master")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(master_index), SoundEffects.volume_db(0.25)), "Master volume must be applied once at the bus")
	main.audio_muted = true
	main._apply_master_audio_settings()
	assert(AudioServer.is_bus_mute(master_index), "Mute must silence the Master bus")
	main.audio_muted = false
	main.audio_volume = 0.0
	main._apply_master_audio_settings()
	assert(AudioServer.get_bus_volume_db(master_index) <= -70.0, "Zero percent volume must be effectively silent")
	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio, main.ui_audio, main.event_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	quit()
