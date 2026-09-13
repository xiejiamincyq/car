extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const Launcher = preload("res://tests/PlaytestLauncher.gd")
const Config = preload("res://tests/playtest_launch_config.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.persistence_enabled = false
	main.set_process(false)
	main.audio_director.music.set_process(false)
	main.audio_director.apply_bus_settings(0.65, 0.65, 0.65, false)
	for track in Tracks.all():
		Launcher.configure_main(main, Config.parse(PackedStringArray([String(track.id), "pulse_gt", "standard", "611"])))
		main._process(3.1)
		_assert_playing(main)
		for cycle in range(10):
			main._pause_run()
			assert(main.audio_director.music.player.stream_paused)
			main.audio_director.toggle_mute()
			main.audio_director.toggle_mute()
			assert(main.audio_director.music.player.stream_paused, "Unmute while paused must not resume early")
			main._resume_run()
			main._process(3.1)
			_assert_playing(main)
			main.audio_director.finish_music()
			main.audio_director.music.tick(1.0)
			assert(not main.audio_director.music.player.playing)
			main._restart_run()
			main._process(3.1)
			_assert_playing(main)
	print("MUSIC RECOVERY: 4 tracks x 10 pause/mute/resume/finish/restart cycles passed")
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	quit()

func _assert_playing(main) -> void:
	var music = main.audio_director.music
	assert(music.player.stream != null and music.player.playing)
	assert(not music.player.stream_paused and music.player.volume_db > -80.0)
	assert(music.current_track_id == main.current_track.music_id)
