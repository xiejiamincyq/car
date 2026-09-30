extends SceneTree

const Drive = preload("res://scripts/drive_controller.gd")
const Vehicles = preload("res://scripts/catalog/vehicle_catalog.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Config = preload("res://scripts/game_config.gd")

func displacement(speed: float, maximum: float, damage: float = 1.0, direction: float = 1.0, frames: int = 1) -> float:
	var drive = Drive.new(speed, maximum, 0.0, 0.0, 500.0, 10000.0, 0.0, 0.0)
	for frame in range(frames):
		drive.step(0.1 / frames, 0.0, 0.0, direction, maxf(0.0, speed - maximum), 0.0, 1.0, damage)
	return drive.lateral_position

func _init() -> void:
	var low := displacement(0.0, 800.0)
	var mid := displacement(400.0, 800.0)
	var high := displacement(800.0, 800.0)
	assert(low > mid and mid > high, "High speed must gently reduce lateral response")
	assert(high >= low * 0.84, "High-speed reduction must preserve obstacle avoidance authority")
	assert(is_equal_approx(displacement(200.0, 800.0), low), "The low-speed region must retain the original response")
	assert(is_equal_approx(displacement(950.0, 800.0), high), "Overdrive must not cause a steering discontinuity")
	var previous := low
	for speed in range(1, 801):
		var current := displacement(float(speed), 800.0)
		assert(current <= previous + 0.0001 and absf(current - previous) < 0.02, "Steering curve must be continuous and monotonic")
		previous = current
	assert(is_equal_approx(displacement(400.0, 800.0, 0.68), mid * 0.68), "Damage must multiply steering authority once")
	assert(is_equal_approx(displacement(400.0, 800.0, 1.0, -1.0), -mid), "Left and right must remain symmetric")
	assert(is_equal_approx(displacement(400.0, 800.0, 1.0, 1.0, 12), mid), "Constant-speed steering must be frame-rate independent")
	for profile in Vehicles.all():
		assert(is_equal_approx(displacement(float(profile.max_speed), float(profile.max_speed)), high), "All six cars must share the normalized curve")
		for track in Tracks.all():
			var authority := float(profile.steering_speed) * float(track.steering_multiplier) * 0.85 * 0.68
			var lane_change_seconds := (2.0 * Config.ROAD_HALF_WIDTH / Config.ROAD_LANE_COUNT) / authority
			assert(lane_change_seconds < Config.LANE_EVENT_WARNING_SECONDS, "Even damaged high-speed cars must retain a one-lane response within construction warning time")
	quit()
