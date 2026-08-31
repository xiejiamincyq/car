extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.audio_director.ui_audio.bus == &"Effects" and main.audio_director.event_audio.bus == &"Effects", "New cue channels must route through Effects")
	main.audio_director.muted = false
	main.audio_director.master_volume = 0.65
	main.audio_director.play_cue("near_miss")
	assert(main.audio_director.last_audio_cue == "near_miss" and main.audio_director.event_audio.stream == main.audio_director.cue_catalog.near_miss, "Near misses must select their distinct event cue")
	main.run.begin_countdown(3.0)
	main.audio_director.last_countdown_value = -1
	main.audio_director.update_countdown_cue(main.run.countdown_remaining)
	assert(main.audio_director.last_audio_cue == "countdown", "Countdown number changes must trigger a cue")
	main.audio_director.last_audio_cue = ""
	main.run.countdown_remaining = 0.01
	main._process(0.02)
	assert(main.run.phase == main.RunState.Phase.RUNNING and main.audio_director.last_audio_cue == "countdown_go", "Countdown completion must play a distinct GO cue")
	main.feedback.tick(0.0, 10.0, 0)
	main.audio_director.last_fuel_audio_tier = main.GameFeedback.FuelTier.NORMAL
	main.audio_director.update_low_fuel_cue(main.feedback.low_fuel_tier, main.GameFeedback.FuelTier.NORMAL)
	assert(main.audio_director.last_audio_cue == "low_fuel", "Crossing a fuel warning tier must trigger the low-fuel cue")
	main.traffic.lane_events.state = main.LaneEventDirector.State.WARNING
	main.audio_director.last_lane_audio_state = main.LaneEventDirector.State.IDLE
	main.audio_director.update_lane_event_cue(main.traffic.lane_events.state, main.LaneEventDirector.State.WARNING, main.LaneEventDirector.State.CLOSED)
	assert(main.audio_director.last_audio_cue == "lane_warning", "A new lane closure warning must trigger its cue")
	main.traffic.lane_events.state = main.LaneEventDirector.State.CLOSED
	main.audio_director.update_lane_event_cue(main.traffic.lane_events.state, main.LaneEventDirector.State.WARNING, main.LaneEventDirector.State.CLOSED)
	assert(main.audio_director.last_audio_cue == "lane_closed", "The moment a warned lane closes must have a distinct confirmation cue")
	main.audio_director.play_cue("run_clear")
	main.run.phase = main.RunState.Phase.RUN_CLEAR
	main._process(0.0)
	assert(main.audio_director.event_audio.playing, "The result screen must not cut off the run-clear cue on its next frame")
	main.audio_director.muted = true
	main.audio_director.last_audio_cue = ""
	main.audio_director.play_cue("checkpoint")
	assert(main.audio_director.last_audio_cue.is_empty(), "Muted cues must not enter the playback route")
	main.audio_director.stop_run_audio()
	main.audio_director.ui_audio.stop()
	for player in [main.audio_director.collision_audio, main.audio_director.engine_audio, main.audio_director.acceleration_audio, main.audio_director.pickup_audio, main.audio_director.warning_audio, main.audio_director.ui_audio, main.audio_director.event_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	quit()
