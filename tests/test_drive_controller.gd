extends SceneTree

const DriveController = preload("res://scripts/drive_controller.gd")

func _init() -> void:
	var controller = DriveController.new(100.0, 400.0, 100.0, 200.0, 300.0)

	controller.step(1.0, 1.0, 0.0)
	assert(is_equal_approx(controller.speed, 200.0), "Accelerating should increase speed")

	controller.step(2.0, 1.0, 0.0)
	assert(is_equal_approx(controller.speed, 400.0), "Speed must clamp to maximum")
	controller.speed = 390.0
	controller.step(0.5, 1.0, 0.0, 0.0, 100.0, 100.0)
	assert(is_equal_approx(controller.speed, 490.0), "Temporary overdrive bonuses must raise acceleration and the speed ceiling without changing the base maximum")
	assert(is_equal_approx(controller.max_speed, 400.0), "Overdrive must not permanently mutate the vehicle profile's maximum speed")
	controller.speed = 400.0

	controller.step(1.0, 0.0, 1.0)
	assert(is_equal_approx(controller.speed, 200.0), "Braking should lower speed and clamp back to the base limit")
	controller.step(2.0, 0.0, 1.0)
	assert(is_zero_approx(controller.speed), "Braking must clamp speed to zero")

	controller.reset()
	controller.step(1.0, 0.0, 0.0)
	assert(controller.speed < 100.0 and controller.speed >= 50.0, "Releasing the throttle must add gentle rolling resistance")
	var coast_speed: float = controller.speed
	controller.step(1.0, 1.0, 0.0)
	assert(controller.speed > coast_speed, "Throttle must overcome rolling resistance")

	var safe_controller = DriveController.new(100.0, 400.0, 100.0, 200.0, 300.0, 300.0, 30.0)
	safe_controller.step(1.0, 0.0, 0.0, 1.0)
	assert(is_equal_approx(safe_controller.lateral_position, 270.0), "Right edge must keep the entire car inside the road")
	safe_controller.step(2.0, 0.0, 0.0, -1.0)
	assert(is_equal_approx(safe_controller.lateral_position, -270.0), "Left edge must keep the entire car inside the road")
	safe_controller.reset()
	assert(is_zero_approx(safe_controller.lateral_position), "Reset must return the car to the road center")

	quit()
