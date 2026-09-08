extends SceneTree

const Profile = preload("res://scripts/player_vehicle_profile.gd")
const Catalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const Visual = preload("res://scripts/vehicle_visual_animation.gd")

func _init() -> void:
	for car in Catalog.all():
		var rotation := Profile.texture_rotation(car)
		assert(is_equal_approx(rotation, PI), "Audited player source art faces down and needs a half turn")
		assert(Vector2.DOWN.rotated(rotation).is_equal_approx(Vector2.UP))
		for direction in [-1.0, 1.0]:
			var forward := Vector2.DOWN.rotated(rotation + Visual.steering_rotation(direction))
			assert(signf(forward.x) == direction and forward.y < 0.0, "The nose must lean toward the steering input")
	assert(is_zero_approx(Visual.traffic_facing_rotation()), "Correct NPC source art must not be flipped")
	quit()
