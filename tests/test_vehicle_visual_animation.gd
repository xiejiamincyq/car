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

	assert(is_zero_approx(VehicleVisualAnimation.brake_light_alpha(0.0, 0.0)), "Brake lights must be off without brake input")
	var brake_alpha := VehicleVisualAnimation.brake_light_alpha(0.12, 1.0)
	assert(brake_alpha >= 0.55 and brake_alpha <= 1.0, "Brake lights must pulse within a readable bounded range")
	assert(is_zero_approx(VehicleVisualAnimation.brake_streak_length(500.0, 760.0, 0.0)), "Tire streaks must be absent without braking")
	var streak_length := VehicleVisualAnimation.brake_streak_length(500.0, 760.0, 1.0)
	assert(streak_length >= 10.0 and streak_length <= 54.0, "Braking streaks must scale with speed but remain bounded")

	assert(VehicleVisualAnimation.finish_emblem_scale(0.0) < 1.0, "The finish emblem must enter from a smaller scale")
	assert(VehicleVisualAnimation.finish_emblem_scale(0.35) <= 1.16, "The finish emblem overshoot must stay subtle")
	assert(is_equal_approx(VehicleVisualAnimation.finish_emblem_scale(1.0), 1.0), "The finish emblem must settle exactly at normal scale")
	assert(absf(VehicleVisualAnimation.finish_emblem_rotation(0.3)) <= 0.12, "The finish emblem rotation must remain bounded")
	assert(is_zero_approx(VehicleVisualAnimation.finish_emblem_rotation(1.0)), "The finish emblem must settle upright")

	assert(is_equal_approx(VehicleVisualAnimation.steering_rotation(1.0), deg_to_rad(15.0)), "Full right steering must lean the car fifteen degrees right")
	assert(is_equal_approx(VehicleVisualAnimation.steering_rotation(-1.0), deg_to_rad(-15.0)), "Full left steering must lean the car fifteen degrees left")
	assert(is_zero_approx(VehicleVisualAnimation.steering_rotation(0.0)), "A centered wheel must keep the car upright")
	assert(is_zero_approx(VehicleVisualAnimation.traffic_facing_rotation()), "Top-down NPC source art must share the player's upright race direction")
	assert(is_zero_approx(VehicleVisualAnimation.traffic_lane_change_rotation(0.0, 1.0, false)), "An NPC must remain upright while only its turn signal is warning")
	assert(is_equal_approx(VehicleVisualAnimation.traffic_lane_change_rotation(0.5, 1.0, true), deg_to_rad(15.0)), "An NPC changing right must lean fifteen degrees at the midpoint")
	assert(is_equal_approx(VehicleVisualAnimation.traffic_lane_change_rotation(1.5, 1.0, true), deg_to_rad(-15.0)), "An NPC changing left must lean fifteen degrees toward the target lane")
	assert(is_zero_approx(VehicleVisualAnimation.traffic_lane_change_rotation(1.0, 1.0, true)), "An NPC must settle upright when it reaches the target lane")
	var corrected_size: Vector2 = VehicleVisualAnimation.corrected_vehicle_size(Vector2(80.0, 112.0))
	assert(corrected_size.y >= 136.0 and corrected_size.x / corrected_size.y <= 0.60, "Vehicle rendering must correct the source art's flattened silhouette")
	assert(VehicleVisualAnimation.speed_line_count(700.0, 760.0) > VehicleVisualAnimation.speed_line_count(250.0, 760.0), "High speed must produce denser motion feedback")
	quit()
