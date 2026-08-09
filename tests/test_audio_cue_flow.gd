extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.ui_audio.bus == &"Effects" and main.event_audio.bus == &"Effects", "New cue channels must route through Effects")
	main.audio_muted = false
	main.audio_volume = 0.65
	main._play_cue("near_miss")
	assert(main.last_audio_cue == "near_miss" and main.event_audio.stream == main.cue_catalog.near_miss, "Near misses must select their distinct event cue")
	main.run.begin_countdown(3.0)
	main.last_countdown_value = -1
	main._update_countdown_cue()
	assert(main.last_audio_cue == "countdown", "Countdown number changes must trigger a cue")
	main.feedback.tick(0.0, 10.0, 0)
	main.last_fuel_audio_tier = main.GameFeedback.FuelTier.NORMAL
	main._update_low_fuel_cue()
	assert(main.last_audio_cue == "low_fuel", "Crossing a fuel warning tier must trigger the low-fuel cue")
	main.traffic.lane_events.state = main.LaneEventDirector.State.WARNING
	main.last_lane_audio_state = main.LaneEventDirector.State.IDLE
	main._update_lane_event_cue()
	assert(main.last_audio_cue == "lane_warning", "A new lane closure warning must trigger its cue")
	main._play_cue("run_clear")
	main.run.phase = main.RunState.Phase.RUN_CLEAR
	main._process(0.0)
	assert(main.event_audio.playing, "The result screen must not cut off the run-clear cue on its next frame")
	main.audio_muted = true
	main.last_audio_cue = ""
	main._play_cue("checkpoint")
	assert(main.last_audio_cue.is_empty(), "Muted cues must not enter the playback route")
	main._stop_run_audio()
	main.ui_audio.stop()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio, main.ui_audio, main.event_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	quit()
