extends SceneTree

const DriveController = preload("res://scripts/drive_controller.gd")

func _init() -> void:
	var controller = DriveController.new(100.0, 400.0, 100.0, 200.0, 300.0)

	controller.step(1.0, 1.0, 0.0)
	assert(is_equal_approx(controller.speed, 200.0), "Accelerating should increase speed")

	controller.step(2.0, 1.0, 0.0)
	assert(is_equal_approx(controller.speed, 400.0), "Speed must clamp to maximum")

	controller.step(1.0, 0.0, 1.0)
	assert(is_equal_approx(controller.speed, 200.0), "Braking should lower speed")

	controller.reset()
	controller.step(1.0, 0.0, 0.0)
	assert(is_equal_approx(controller.speed, 100.0), "Coasting should retain current speed in the prototype")

	controller.step(1.0, 0.0, 0.0, 1.0)
	assert(is_equal_approx(controller.lateral_position, 300.0), "Steering should move by steering speed")
	controller.step(1.0, 0.0, 0.0, 1.0)
	assert(is_equal_approx(controller.lateral_position, 300.0), "Steering must clamp to road boundary")

	quit()
