extends SceneTree

const Sounds = preload("res://scripts/sound_effects.gd")
const Renderer = preload("res://scripts/coin_renderer.gd")

func _init() -> void:
	var sound := Sounds.create_coin_pickup()
	assert(sound.get_length() >= 0.18 and sound.get_length() <= 0.28, "Coin bell needs a short audible decay, not a swept beep")
	var peak := 0
	var jump := 0
	var previous := 0
	for i in range(0, sound.data.size(), 2):
		var sample := sound.data.decode_s16(i)
		peak = maxi(peak, absi(sample))
		jump = maxi(jump, absi(sample-previous))
		previous = sample
	assert(peak > 1500 and peak < 14000, "Bell must remain audible and leave mix headroom")
	assert(absi(sound.data.decode_s16(0)) < 30 and absi(previous) < 30, "Bell must fade in/out without boundary clicks")
	assert(jump < 4500, "Bell attack must not create harsh sample jumps")
	for progress in [0.0, 0.25, 0.5, 1.0]:
		for particle in range(10):
			var point: Vector2 = Renderer.burst_particle_offset(progress, particle, 10)
			assert(point.is_finite() and point.length() < 90, "Coin particles must stay bounded and not obstruct adjacent lanes")
			if progress > 0.0:
				assert(point.y > 0.0, "Pickup fragments must trail toward the car rear (screen down), not fly ahead")
	quit()
