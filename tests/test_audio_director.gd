extends SceneTree

const AudioDirector = preload("res://scripts/audio/audio_director.gd")
const SoundEffects = preload("res://scripts/sound_effects.gd")
const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := AudioDirector.new()
	root.add_child(director)
	await process_frame

	for player in director.effect_players():
		assert(player.bus == &"Effects", "AudioDirector must keep every effect channel on the Effects bus")
	assert(director.overdrive_start_audio in director.effect_players() and director.overdrive_loop_audio in director.effect_players() and director.overdrive_end_audio in director.effect_players(), "All three mechanical overdrive layers must be managed effect channels")
	assert(director.music.player.bus == &"Music", "AudioDirector must expose music only through MusicDirector")

	director.apply_bus_settings(0.80, 0.40, 0.70, false)
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")), SoundEffects.volume_db(0.80)), "AudioDirector must apply Master volume")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), SoundEffects.volume_db(0.40)), "AudioDirector must apply independent Music volume")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects")), SoundEffects.volume_db(0.70)), "AudioDirector must apply independent Effects volume")

	director.play_effect(director.collision_audio)
	assert(director.collision_audio.playing, "Enabled effects must play through the director")
	director.apply_bus_settings(0.80, 0.40, 0.70, true)
	assert(not director.collision_audio.playing, "Master mute must stop active effects immediately")
	director.play_cue("checkpoint")
	assert(director.last_audio_cue.is_empty(), "Muted cues must not enter the playback route")

	director.apply_bus_settings(0.80, 0.40, 0.70, false)
	director.play_cue("checkpoint")
	assert(director.last_audio_cue == "checkpoint" and director.event_audio.playing, "Unmuted named cues must use the event channel")
	director.update_overdrive(true, 0.5)
	assert(director.overdrive_start_audio.playing and director.overdrive_loop_audio.playing, "Overdrive activation must play ignition and begin the turbine loop")
	director.pause_for_gameplay()
	assert(not director.overdrive_loop_audio.playing, "Pausing gameplay must stop the turbine loop immediately")
	director.update_overdrive(true, 0.5)
	assert(director.overdrive_loop_audio.playing, "An active overdrive must restore its turbine loop after gameplay resumes")
	director.update_overdrive(false, 0.0)
	assert(not director.overdrive_loop_audio.playing and director.overdrive_end_audio.playing, "Overdrive exit must stop the turbine and play its release cue")
	var lane_changer := TrafficVehicle.new(TrafficVehicle.SIGNAL_CHANGE_KIND, 0, 120.0, 1, 0, 200.0)
	lane_changer.warning_started = true
	lane_changer.warning_remaining = 0.10
	director.update_driving(0.02, 0.5, false, [lane_changer])
	assert(director.warning_audio.playing, "Shorter lane-change warnings must still trigger their audible turn signal")
	director.stop_driving_audio()
	await process_frame
	director.begin_music_countdown(&"neon_coast")
	assert(director.music.player.stream != null and director.music.target_volume_db <= -3.0, "Finished catalog tracks must load with effects-readable mix headroom")
	director.begin_music_countdown(&"storm_ridge")
	director.begin_music_race()
	assert(director.music.current_track_id == &"storm_ridge" and director.music.phase == director.music.Phase.PLAYING, "Main-facing music calls must forward track and lifecycle state")
	director.apply_bus_settings(0.80, 0.40, 0.70, true)
	assert(director.music.phase == director.music.Phase.PLAYING, "Master mute must preserve the active music lifecycle so unmute can resume it")
	director.apply_bus_settings(0.80, 0.40, 0.70, false)
	assert(director.music.phase == director.music.Phase.PLAYING, "Unmuting must retain the selected track and active lifecycle")
	director.pause_for_gameplay()
	assert(director.music.phase == director.music.Phase.PAUSED and not director.event_audio.playing, "Gameplay pause must silence effects and pause music")
	director.resume_music_countdown()
	assert(director.music.phase == director.music.Phase.FADING_IN, "Gameplay resume must return music through countdown fade-in")

	director.shutdown()
	for player in director.effect_players():
		assert(player.stream == null, "AudioDirector shutdown must release effect streams")
	director.queue_free()
	await process_frame
	await process_frame
	await process_frame
	quit()
