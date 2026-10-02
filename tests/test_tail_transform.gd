extends SceneTree

const Effects = preload("res://scripts/race_effect_renderer.gd")
const Profile = preload("res://scripts/player_vehicle_profile.gd")
const Catalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const VehicleAnimation = preload("res://scripts/vehicle_visual_animation.gd")
var failures: Array[String] = []
var samples := 0

func _init() -> void:
	for vehicle in Catalog.all():
		var texture: Texture2D = load(vehicle.texture_path)
		var size := Profile.visual_size(vehicle, texture.get_size())
		var source := texture.get_image()
		for side in [-1.0, 1.0]:
			var exhaust := Effects.exhaust_local_position(size, side)
			var column := roundi((exhaust.x / size.x + 0.5) * source.get_width())
			var last_opaque := source.get_height() - 1
			while last_opaque >= 0 and source.get_pixel(column, last_opaque).a < 0.5:
				last_opaque -= 1
			var bumper_y := (float(last_opaque) / source.get_height() - 0.5) * size.y
			_check(last_opaque >= 0 and bumper_y - exhaust.y >= 0.0 and bumper_y - exhaust.y <= 2.5,
				"%s exhaust must meet its actual opaque rear bumper within 2.5 local pixels" % vehicle.id)
		for degrees in [0.0, -15.0, 15.0]:
			for scale in [Vector2.ONE, VehicleAnimation.collision_scale(0.23)]:
				for wobble in [0.0, VehicleAnimation.collision_rotation(0.23, 1.0) + VehicleAnimation.damage_wobble(0.4, 2, false)]:
					_check_pose(size, deg_to_rad(degrees) + wobble, scale)
	print("TAIL_GEOMETRY samples=", samples, " vehicles=6 failures=", failures.size())
	for failure in failures: push_error(failure)
	print("TEST_COMPLETE test_tail_transform.gd")
	quit(0 if failures.is_empty() else 1)

func _check_pose(size: Vector2, angle: float, scale: Vector2) -> void:
	samples += 1
	var center := Vector2(640, 592)
	var shake := Vector2(7, -4)
	var body := Effects.body_effect_transform(center, angle, scale)
	for side in [-1.0, 1.0]:
		var exhaust := Effects.exhaust_local_position(size, side)
		var expected := center + _rotate_scaled(exhaust, angle, scale)
		_check((body * exhaust).distance_to(expected) < 0.001, "Exhaust origin must rotate and scale with the body")
		for flame_length in [16.0, 54.0]:
			var direction: Vector2 = body * (exhaust + Vector2(0, flame_length)) - body * exhaust
			_check(direction.distance_to(_rotate_scaled(Vector2(0, flame_length), angle, scale)) < 0.001,
				"Normal and overdrive flame axes must rotate with the body, not screen-down")
	for layer in [0, 1]:
		for source_correction in [0.0, PI]:
			var texture_angle: float = angle + source_correction
			var ghost := Effects.afterimage_transform(center, texture_angle, angle, scale, shake, layer)
			var expected_origin := shake + center + _rotate_scaled(Vector2(0, 27.0 * (layer + 1)), angle, scale)
			_check(ghost.origin.distance_to(expected_origin) < 0.001, "Afterimage origin must use body angle even when source texture needs a half-turn")
			_check(absf(angle_difference(ghost.get_rotation(), texture_angle)) < 0.001,
				"Afterimage texture must retain its independent source orientation correction")
			_check(ghost.get_scale().distance_to(scale) < 0.001, "Afterimages must preserve the body's impact scale")

func _rotate_scaled(local: Vector2, angle: float, scale: Vector2) -> Vector2:
	return Vector2(local.x * scale.x * cos(angle) - local.y * scale.y * sin(angle),
		local.x * scale.x * sin(angle) + local.y * scale.y * cos(angle))

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
