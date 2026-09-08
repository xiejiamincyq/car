extends SceneTree

const Traffic = preload("res://scripts/traffic_director.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Vehicles = preload("res://scripts/catalog/vehicle_catalog.gd")
const Difficulty = preload("res://scripts/difficulty_profile.gd")
const Config = preload("res://scripts/game_config.gd")

func _init() -> void:
	var cases := 0
	for track in Tracks.all():
		for car in Vehicles.all():
			for difficulty in range(3):
				for seed in [611, 2026, 9001]:
					var traffic := Traffic.new(seed)
					traffic.configure_track(track)
					traffic.configure_difficulty(Difficulty.for_index(difficulty))
					var speed := 280.0
					for step in range(300):
						# 60-second world simulation: acceleration, braking and overdrive-speed windows.
						var target: float = car.max_speed
						if step >= 90 and step < 115: target += Config.OVERDRIVE_SPEED_BONUS
						if step >= 160 and step < 190: target = 120.0
						speed = move_toward(speed, target, float(car.acceleration if target > speed else car.braking) * 0.2)
						traffic.set_difficulty_stage(mini(3, step / 75))
						traffic.tick(0.2, speed, 1)
						assert(traffic.all_active_spawns_are_fair(), "Traffic matrix failed: %s/%s/%d/%d frame %d" % [track.id, car.id, difficulty, seed, step])
						assert(traffic.vehicles.size() <= traffic.max_active_vehicles)
					cases += 1
	assert(cases == 216)
	print("TOUR TRAFFIC MATRIX: 216 cases x 60 simulated seconds passed")
	quit()
