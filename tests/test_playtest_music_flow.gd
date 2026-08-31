extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const PlaytestLauncher = preload("res://tests/PlaytestLauncher.gd")
const PlaytestLaunchConfig = preload("res://tests/playtest_launch_config.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var config := PlaytestLaunchConfig.parse(PackedStringArray(["neon_coast", "pulse_gt", "standard", "611"]))
	PlaytestLauncher.configure_main(main, config)

	assert(main.audio_director.music.current_track_id == &"neon_coast", "A Neon Coast playtest must select the Neon Coast music track")
	assert(main.audio_director.music.player.stream != null, "A playtest must load the selected track's finished music asset")
	assert(main.audio_director.music.phase == main.audio_director.music.Phase.FADING_IN, "A playtest must enter the countdown music lifecycle")
	assert(main.audio_director.music.player.playing, "An unmuted playtest must actually start music playback")

	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	await process_frame
	await process_frame
	quit()
