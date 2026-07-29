extends SceneTree

const SoundEffects = preload("res://scripts/sound_effects.gd")

func _init() -> void:
	var engine := SoundEffects.create_engine_loop()
	assert(engine is AudioStreamWAV and engine.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Engine audio must be an original looping WAV")
	for effect in [SoundEffects.create_acceleration(), SoundEffects.create_pickup(), SoundEffects.create_warning()]:
		assert(effect is AudioStreamWAV and not effect.data.is_empty(), "Each gameplay cue must be a generated playable WAV")
	assert(SoundEffects.volume_db(0.0) <= -70.0, "Mute volume must be effectively silent")
	assert(SoundEffects.volume_db(0.5) < SoundEffects.volume_db(1.0), "Volume control must be monotonic")
	quit()
