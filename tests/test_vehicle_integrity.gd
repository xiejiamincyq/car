extends SceneTree

const VehicleIntegrity = preload("res://scripts/vehicle_integrity.gd")

func _init() -> void:
	var integrity := VehicleIntegrity.new()
	assert(is_equal_approx(integrity.current, 100.0) and integrity.condition() == VehicleIntegrity.Condition.HEALTHY, "A run must begin at full vehicle integrity")
	integrity.apply_damage(30.0)
	assert(is_equal_approx(integrity.current, 70.0) and integrity.condition() == VehicleIntegrity.Condition.DAMAGED, "Seventy percent must activate the first damage node")
	assert(is_equal_approx(integrity.max_speed_multiplier(), 0.92) and is_equal_approx(integrity.steering_multiplier(), 0.88), "The first damage node must modestly reduce speed and steering")
	integrity.apply_damage(40.0)
	assert(is_equal_approx(integrity.current, 30.0) and integrity.condition() == VehicleIntegrity.Condition.CRITICAL, "Thirty percent must activate the critical damage node")
	assert(is_equal_approx(integrity.max_speed_multiplier(), 0.78) and is_equal_approx(integrity.steering_multiplier(), 0.68), "Critical damage must substantially reduce speed and lane-change authority")
	integrity.apply_damage(10.0)
	assert(is_equal_approx(integrity.current, 20.0) and not integrity.is_failed(), "Exactly twenty percent must remain barely driveable")
	integrity.apply_damage(0.1)
	assert(integrity.is_failed() and integrity.condition() == VehicleIntegrity.Condition.FAILED, "Integrity below twenty percent must fail immediately")
	assert(is_equal_approx(VehicleIntegrity.damage_for_impact(0.0, 760.0), 12.0), "A low-speed contact must still cause the minimum integrity loss")
	assert(is_equal_approx(VehicleIntegrity.damage_for_impact(760.0, 760.0), 22.0), "A top-speed impact must use the bounded maximum integrity loss")
	integrity.reset()
	integrity.current = 85.0
	assert(is_equal_approx(integrity.max_speed_multiplier(), 0.96) and is_equal_approx(integrity.steering_multiplier(), 0.94), "Performance interpolates continuously between nodes")
	integrity.current = 20.0
	assert(is_equal_approx(integrity.max_speed_multiplier(), 0.72) and is_equal_approx(integrity.steering_multiplier(), 0.60))
	integrity.reset()
	assert(is_equal_approx(integrity.current, 100.0) and integrity.condition() == VehicleIntegrity.Condition.HEALTHY, "Restarting must restore full integrity")
	quit()
