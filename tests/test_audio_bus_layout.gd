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
	for player in [main.audio_director.collision_audio, main.audio_director.engine_audio, main.audio_director.acceleration_audio, main.audio_director.pickup_audio, main.audio_director.warning_audio, main.audio_director.ui_audio, main.audio_director.event_audio]:
		assert(player.bus == &"Effects", "Every current gameplay player must route through Effects")
	main.audio_director.master_volume = 0.25
	main.audio_director.music_volume = 0.40
	main.audio_director.effects_volume = 0.70
	main.audio_director.muted = false
	main.audio_director.apply_bus_settings(main.audio_director.master_volume, main.audio_director.music_volume, main.audio_director.effects_volume, main.audio_director.muted)
	var master_index := AudioServer.get_bus_index("Master")
	var music_index := AudioServer.get_bus_index("Music")
	var effects_index := AudioServer.get_bus_index("Effects")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(master_index), SoundEffects.volume_db(0.25)), "Master volume must be applied once at the bus")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(music_index), SoundEffects.volume_db(0.40)), "Music volume must be independently applied to the Music bus")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(effects_index), SoundEffects.volume_db(0.70)), "Effects volume must be independently applied to the Effects bus")
	main._save_preferences()
	assert(is_equal_approx(float(main.save_data.settings.music_volume), 0.40), "Music volume must persist independently")
	assert(is_equal_approx(float(main.save_data.settings.effects_volume), 0.70), "Effects volume must persist independently")
	main.audio_director.muted = true
	main.audio_director.apply_bus_settings(main.audio_director.master_volume, main.audio_director.music_volume, main.audio_director.effects_volume, main.audio_director.muted)
	assert(AudioServer.is_bus_mute(master_index), "Mute must silence the Master bus")
	main.audio_director.muted = false
	main.audio_director.master_volume = 0.0
	main.audio_director.apply_bus_settings(main.audio_director.master_volume, main.audio_director.music_volume, main.audio_director.effects_volume, main.audio_director.muted)
	assert(AudioServer.get_bus_volume_db(master_index) <= -70.0, "Zero percent volume must be effectively silent")
	main.audio_director.stop_run_audio()
	for player in [main.audio_director.collision_audio, main.audio_director.engine_audio, main.audio_director.acceleration_audio, main.audio_director.pickup_audio, main.audio_director.warning_audio, main.audio_director.ui_audio, main.audio_director.event_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	quit()
