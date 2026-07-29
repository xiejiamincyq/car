class_name SoundEffects
extends RefCounted

static func create_engine_loop() -> AudioStreamWAV:
	var stream := _make_wave(92.0, 0.44, 0.22, true, 1.8)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	return stream

static func create_acceleration() -> AudioStreamWAV:
	return _make_chirp(260.0, 520.0, 0.10, 0.32)

static func create_pickup() -> AudioStreamWAV:
	return _make_chirp(480.0, 880.0, 0.14, 0.34)

static func create_warning() -> AudioStreamWAV:
	return _make_chirp(760.0, 610.0, 0.12, 0.28)

static func volume_db(level: float) -> float:
	return linear_to_db(clampf(level, 0.0, 1.0))

static func _make_chirp(start_frequency: float, end_frequency: float, duration: float, gain: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for index in sample_count:
		var progress := float(index) / sample_count
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / mix_rate
		var envelope := sin(progress * PI)
		data.encode_s16(index * 2, int(sin(phase) * envelope * gain * 30000.0))
	return _stream_from_data(data, mix_rate)

static func _make_wave(frequency: float, duration: float, gain: float, _looping: bool, harmonic_gain: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in sample_count:
		var phase := TAU * frequency * float(index) / mix_rate
		var value := (sin(phase) + sin(phase * 2.0) * harmonic_gain * 0.25) * gain
		data.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 30000.0))
	return _stream_from_data(data, mix_rate)

static func _stream_from_data(data: PackedByteArray, mix_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
