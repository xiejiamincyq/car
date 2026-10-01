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

static func create_overdrive_ignition() -> AudioStreamWAV:
	return _make_chirp(150.0, 760.0, 0.24, 0.38)

static func create_overdrive_loop() -> AudioStreamWAV:
	var stream := _make_wave(138.0, 0.36, 0.18, true, 1.35)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	return stream

static func create_overdrive_release() -> AudioStreamWAV:
	return _make_chirp(620.0, 130.0, 0.22, 0.30)

static func create_pickup() -> AudioStreamWAV:
	return _make_chirp(480.0, 880.0, 0.14, 0.34)

static func create_coin_pickup() -> AudioStreamWAV:
	# Two stable musical pitches with a soft mallet attack and short bell decay.
	var rate := 44100
	var duration := 0.22
	var data := PackedByteArray()
	data.resize(int(rate*duration)*2)
	for index in range(data.size()/2):
		var time := float(index)/rate
		var value := 0.0
		for note in range(2):
			var age := time-float(note)*0.035
			if age < 0: continue
			var frequency := 1174.66 if note == 0 else 1567.98
			var attack := minf(1.0, age/0.004)
			var release := clampf((duration-time)/0.035, 0.0, 1.0)
			var phase := TAU*frequency*age
			value += (sin(phase)*0.68+sin(phase*2.76)*0.16+sin(phase*5.4)*0.04)*attack*exp(-age*24.0)*release*0.28
		data.encode_s16(index*2, int(clampf(value, -0.4, 0.4)*30000.0))
	return _stream_from_data(data, rate)

static func create_warning() -> AudioStreamWAV:
	return _make_chirp(760.0, 610.0, 0.12, 0.28)

static func create_cue_catalog() -> Dictionary:
	return {
		"ui_move": _make_chirp(320.0, 380.0, 0.05, 0.18),
		"ui_confirm": _make_chirp(440.0, 660.0, 0.09, 0.24),
		"ui_cancel": _make_chirp(300.0, 180.0, 0.11, 0.22),
		"near_miss": _make_chirp(980.0, 420.0, 0.16, 0.22),
		"combo": _make_chirp(620.0, 920.0, 0.13, 0.24),
		"countdown": _make_chirp(520.0, 500.0, 0.08, 0.26),
		"countdown_go": _make_chirp(540.0, 1120.0, 0.24, 0.30),
		"checkpoint": _make_chirp(540.0, 980.0, 0.22, 0.28),
		"run_clear": _make_chirp(440.0, 1040.0, 0.38, 0.25),
		"low_fuel": _make_chirp(220.0, 170.0, 0.24, 0.25),
		"lane_warning": _make_pulsed_tone(760.0, 0.42, 0.30, 3),
		"lane_closed": _make_chirp(260.0, 110.0, 0.30, 0.30),
	}

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

static func _make_pulsed_tone(frequency: float, duration: float, gain: float, pulse_count: int) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in sample_count:
		var progress := float(index) / sample_count
		var pulse_progress := fmod(progress * maxi(1, pulse_count), 1.0)
		var envelope := sin(pulse_progress * PI)
		var phase := TAU * frequency * float(index) / mix_rate
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
