extends SceneTree

const SoundEffects = preload("res://scripts/sound_effects.gd")

func _init() -> void:
	var engine := SoundEffects.create_engine_loop()
	assert(engine is AudioStreamWAV and engine.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Engine audio must be an original looping WAV")
	for effect in [SoundEffects.create_acceleration(), SoundEffects.create_pickup(), SoundEffects.create_warning()]:
		assert(effect is AudioStreamWAV and not effect.data.is_empty(), "Each gameplay cue must be a generated playable WAV")
	var cues: Dictionary = SoundEffects.create_cue_catalog()
	var expected_names := ["ui_move", "ui_confirm", "ui_cancel", "near_miss", "combo", "countdown", "checkpoint", "run_clear", "low_fuel", "lane_warning"]
	assert(cues.keys().size() == expected_names.size(), "The cue catalog must expose every planned F6 sound exactly once")
	var fingerprints := {}
	for cue_name in expected_names:
		assert(cues.has(cue_name), "Missing generated cue: %s" % cue_name)
		var cue: AudioStreamWAV = cues[cue_name]
		var duration := float(cue.data.size()) / 2.0 / cue.mix_rate
		assert(duration >= 0.04 and duration <= 0.6, "%s must have a short, usable duration" % cue_name)
		var peak := 0
		for byte_index in range(0, cue.data.size(), 2):
			peak = maxi(peak, absi(cue.data.decode_s16(byte_index)))
		assert(peak > 0 and peak <= 28500, "%s must be audible without clipping" % cue_name)
		fingerprints[hash(cue.data)] = true
	assert(fingerprints.size() == expected_names.size(), "Each gameplay meaning must have a distinguishable waveform")
	assert(SoundEffects.volume_db(0.0) <= -70.0, "Mute volume must be effectively silent")
	assert(SoundEffects.volume_db(0.5) < SoundEffects.volume_db(1.0), "Volume control must be monotonic")
	quit()
