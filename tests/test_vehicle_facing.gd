extends SceneTree

const Profile = preload("res://scripts/player_vehicle_profile.gd")
const Catalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const Visual = preload("res://scripts/vehicle_visual_animation.gd")

func _init() -> void:
	for car in Catalog.all():
		var rotation := Profile.texture_rotation(car)
		var source_forward := Vector2.UP
		assert(is_zero_approx(rotation), "All C sprites already face upward")
		var sprite := Image.load_from_file(car.texture_path)
		assert(sprite.get_size() == Vector2i(800, 1360))
		assert(sprite.get_pixel(0, 0).a == 0.0 and sprite.get_pixel(400, 680).a == 1.0)
		assert(Profile.visual_size(car, sprite.get_size()).is_equal_approx(Vector2(80, 136)))
		assert(source_forward.rotated(rotation).is_equal_approx(Vector2.UP))
		for direction in [-1.0, 1.0]:
			var forward := source_forward.rotated(rotation + Visual.steering_rotation(direction))
			assert(signf(forward.x) == direction and forward.y < 0.0, "The nose must lean toward the steering input")
	assert(is_zero_approx(Visual.traffic_facing_rotation()), "Correct NPC source art must not be flipped")
	var image := Image.load_from_file("res://assets/vehicles/player_driftwing_c.png")
	assert(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(400, 680).a == 1.0, "The new sprite must have real transparency and opaque glass")
	var size := Profile.visual_size(Catalog.get_by_id(&"driftwing"), image.get_size())
	assert(size.is_equal_approx(Vector2(80, 136)), "New plan-view art must scale uniformly, without legacy stretching")
	quit()
