extends SceneTree

const GameConfig = preload("res://scripts/game_config.gd")
const OverdriveController = preload("res://scripts/overdrive_controller.gd")

func _init() -> void:
	var controller = OverdriveController.new()
	assert(controller.observe_accelerate_press(100.0, 100.0) == OverdriveController.ActivationResult.NONE, "The first W press must keep normal acceleration without activating overdrive")
	controller.tick(GameConfig.OVERDRIVE_DOUBLE_TAP_WINDOW - 0.01, 100.0)
	assert(controller.observe_accelerate_press(100.0, 100.0) == OverdriveController.ActivationResult.ACTIVATED, "A second W press inside the double-tap window must activate overdrive")
	assert(controller.is_active(), "A successful double tap must enter the active state")
	assert(controller.observe_accelerate_press(100.0, 100.0) == OverdriveController.ActivationResult.UNAVAILABLE, "Repeated presses must not stack an active overdrive")

	controller.tick(GameConfig.OVERDRIVE_RAMP_IN_SECONDS, 100.0)
	assert(is_equal_approx(controller.intensity(), 1.0), "Overdrive must reach full strength after its ramp-in")
	assert(is_equal_approx(controller.speed_limit_bonus(), GameConfig.OVERDRIVE_SPEED_BONUS), "Full overdrive must add exactly 100 km/h to the speed limit")
	assert(is_equal_approx(controller.acceleration_bonus(), GameConfig.OVERDRIVE_ACCELERATION_BONUS), "Full overdrive must expose its configured acceleration bonus")

	controller.reset()
	controller.observe_accelerate_press(100.0, 100.0)
	controller.tick(GameConfig.OVERDRIVE_DOUBLE_TAP_WINDOW + 0.01, 100.0)
	assert(controller.observe_accelerate_press(100.0, 100.0) == OverdriveController.ActivationResult.NONE, "Two W presses outside the time window must start a new sequence instead of activating")

	controller.reset()
	controller.observe_accelerate_press(9.99, 100.0)
	controller.tick(0.1, 9.99)
	assert(controller.observe_accelerate_press(9.99, 100.0) == OverdriveController.ActivationResult.INSUFFICIENT_FUEL, "Less than ten percent fuel must reject overdrive")
	assert(not controller.is_active(), "A rejected activation must not change the speed limit")

	controller.reset()
	controller.observe_accelerate_press(100.0, 100.0)
	controller.tick(0.1, 100.0)
	controller.observe_accelerate_press(100.0, 100.0)
	var total_extra_fuel := 0.0
	for _step in range(50):
		var drained := controller.tick(0.05, 100.0 - total_extra_fuel)
		total_extra_fuel += drained
	assert(is_equal_approx(total_extra_fuel, 10.0), "One complete overdrive must gradually consume exactly ten percent of the maximum fuel")
	assert(controller.is_cooling_down(), "A completed overdrive must enter cooldown")
	controller.tick(GameConfig.OVERDRIVE_COOLDOWN_SECONDS, 90.0)
	assert(controller.is_ready(), "Overdrive must become available after its cooldown")

	controller.observe_accelerate_press(90.0, 100.0)
	controller.tick(0.1, 90.0)
	controller.observe_accelerate_press(90.0, 100.0)
	controller.tick(0.2, 90.0)
	assert(controller.is_active(), "The controller must support a new activation after cooldown")
	controller.reset()
	assert(controller.is_ready() and is_zero_approx(controller.intensity()), "Restart must clear active overdrive, cooldown, and visual strength")
	quit()
