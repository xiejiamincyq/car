extends SceneTree

const MusicDirector = preload("res://scripts/audio/music_director.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := MusicDirector.new()
	root.add_child(director)
	await process_frame

	assert(director.player.bus == &"Music", "Music playback must route only through the Music bus")
	director.begin_countdown(&"neon_coast")
	assert(director.current_track_id == &"neon_coast" and director.phase == MusicDirector.Phase.FADING_IN, "Countdown must select the requested track and begin the fade-in lifecycle")
	assert(not director.player.playing, "A missing music asset must remain a safe silent default")

	director.begin_race()
	assert(director.phase == MusicDirector.Phase.PLAYING, "Countdown completion must advance music to the playing lifecycle")
	director.pause()
	assert(director.phase == MusicDirector.Phase.PAUSED and director.phase_before_pause == MusicDirector.Phase.PLAYING, "Pause must remember the active lifecycle phase")
	director.resume_countdown()
	assert(director.phase == MusicDirector.Phase.FADING_IN, "Resuming gameplay must re-enter through the safe countdown fade")

	director.begin_countdown(&"freight_harbor")
	assert(director.current_track_id == &"freight_harbor", "Changing tracks must replace the requested music ID")
	director.finish()
	assert(director.phase == MusicDirector.Phase.FADING_OUT, "Results must begin a music fade-out")
	director.tick(MusicDirector.FADE_OUT_SECONDS)
	assert(director.phase == MusicDirector.Phase.STOPPED and not director.player.playing, "Completing the result fade must stop and release playback")

	director.shutdown()
	director.queue_free()
	await process_frame
	quit()
