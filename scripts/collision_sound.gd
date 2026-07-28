class_name CollisionSound
extends RefCounted

static func create_stream() -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(mix_rate * 0.12)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in sample_count:
		var progress := float(index) / sample_count
		var frequency := lerpf(180.0, 70.0, progress)
		var envelope := 1.0 - progress
		var sample := int(sin(TAU * frequency * float(index) / mix_rate) * envelope * 12000.0)
		data.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
