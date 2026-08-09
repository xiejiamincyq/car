extends SceneTree

const VehicleVisualAnimation = preload("res://scripts/vehicle_visual_animation.gd")

func _init() -> void:
	var idle_flame := VehicleVisualAnimation.acceleration_flame_length(0.0, 0.0)
	var powered_flame := VehicleVisualAnimation.acceleration_flame_length(0.13, 0.8)
	assert(is_zero_approx(idle_flame), "Idle vehicles must not draw acceleration flames")
	assert(powered_flame >= 8.0 and powered_flame <= 24.0, "Acceleration flames must be visible and bounded")

	var start_rotation := VehicleVisualAnimation.collision_rotation(VehicleVisualAnimation.COLLISION_DURATION, 1.0)
	var middle_rotation := VehicleVisualAnimation.collision_rotation(VehicleVisualAnimation.COLLISION_DURATION * 0.5, 1.0)
	var finished_rotation := VehicleVisualAnimation.collision_rotation(0.0, 1.0)
	assert(absf(start_rotation) <= VehicleVisualAnimation.MAX_COLLISION_ROTATION, "Collision rotation must stay bounded")
	assert(absf(middle_rotation) <= VehicleVisualAnimation.MAX_COLLISION_ROTATION, "Collision wobble must stay bounded throughout")
	assert(is_zero_approx(finished_rotation), "Collision rotation must settle exactly at rest")

	var impact_scale := VehicleVisualAnimation.collision_scale(VehicleVisualAnimation.COLLISION_DURATION)
	var settled_scale := VehicleVisualAnimation.collision_scale(0.0)
	assert(impact_scale.x > 1.0 and impact_scale.y < 1.0, "A collision must briefly squash and widen the player car")
	assert(settled_scale.is_equal_approx(Vector2.ONE), "Collision scale must return exactly to normal")
	assert(is_equal_approx(VehicleVisualAnimation.collision_ring_alpha(0.0), 0.0), "The impact ring must disappear after the animation")
	quit()
