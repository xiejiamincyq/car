extends SceneTree

const DifficultyProfile = preload("res://scripts/difficulty_profile.gd")
const DriveController = preload("res://scripts/drive_controller.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const RunState = preload("res://scripts/run_state.gd")
const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")

func _init() -> void:
	_assert_resistance_curve_is_speed_driven_but_bounded()
	_assert_positive_acceleration_adds_fuel_load()
	_assert_every_vehicle_can_finish_every_track_at_steady_top_speed()
	_assert_accelerating_to_top_speed_preserves_the_finish_budget()
	quit()

func _assert_resistance_curve_is_speed_driven_but_bounded() -> void:
	var low_speed_load := RunState.resistance_fuel_load(280.0, 760.0)
	var cruise_speed_load := RunState.resistance_fuel_load(560.0, 760.0)
	var top_speed_load := RunState.resistance_fuel_load(760.0, 760.0)
	assert(low_speed_load > 0.0, "Moving at low speed must still consume fuel against resistance")
	assert(is_zero_approx(RunState.resistance_fuel_load(0.0, 760.0)), "A stationary vehicle has no rolling or aerodynamic resistance")
	assert(cruise_speed_load > low_speed_load and top_speed_load > cruise_speed_load, "Fuel resistance must rise continuously with speed")
	assert(top_speed_load < low_speed_load * 1.8, "Top-speed resistance may not dwarf normal driving consumption")

func _assert_positive_acceleration_adds_fuel_load() -> void:
	var steady_load := RunState.fuel_load(560.0, 760.0, 0.0)
	var accelerating_load := RunState.fuel_load(560.0, 760.0, GameConfig.ACCELERATION)
	assert(accelerating_load > steady_load, "Positive acceleration must add fuel consumption on top of resistance")
	assert(is_equal_approx(steady_load, RunState.resistance_fuel_load(560.0, 760.0)), "Steady-speed consumption must contain resistance only")
	assert(RunState.acceleration_fuel_load(-100.0) == 0.0, "Braking or collision deceleration may not be charged as acceleration")
	var drive := DriveController.new(280.0, 760.0, GameConfig.ACCELERATION, GameConfig.BRAKING, GameConfig.STEERING_SPEED)
	drive.speed = drive.max_speed
	var speed_before_step := drive.speed
	drive.step(0.25, 1.0, 0.0)
	assert(is_zero_approx((drive.speed - speed_before_step) / 0.25), "Holding the accelerator at top speed may not create imaginary acceleration fuel load")

func _assert_every_vehicle_can_finish_every_track_at_steady_top_speed() -> void:
	for difficulty_index in range(DifficultyProfile.PROFILES.size()):
		for track in TrackCatalog.all():
			for vehicle in VehicleCatalog.all():
				var run := RunState.new(GameConfig.MAX_FUEL, GameConfig.FUEL_DRAIN_PER_SECOND, GameConfig.FUEL_GRACE_SECONDS)
				run.configure_track(track)
				run.configure_difficulty(DifficultyProfile.for_index(difficulty_index))
				run.start()
				var top_speed := float(vehicle.max_speed)
				var maximum_steps := ceili(float(track.finish_distance) / (top_speed * 0.1 * 0.25)) + 4
				for _step in range(maximum_steps):
					run.tick(0.25, top_speed, top_speed)
					if run.phase != RunState.Phase.RUNNING:
						break
				assert(run.phase == RunState.Phase.RUN_CLEAR, "%s must finish %s at steady top speed on difficulty %d" % [vehicle.id, track.id, difficulty_index])
				assert(run.fuel >= 5.0, "%s must retain a practical fuel margin after %s on difficulty %d: %.2f" % [vehicle.id, track.id, difficulty_index, run.fuel])

func _assert_accelerating_to_top_speed_preserves_the_finish_budget() -> void:
	for difficulty_index in range(DifficultyProfile.PROFILES.size()):
		for track in TrackCatalog.all():
			for vehicle in VehicleCatalog.all():
				var drive := DriveController.new(
					minf(GameConfig.START_SPEED, float(vehicle.max_speed)),
					float(vehicle.max_speed),
					float(vehicle.acceleration),
					float(vehicle.braking),
					float(vehicle.steering_speed)
				)
				var run := RunState.new(GameConfig.MAX_FUEL, GameConfig.FUEL_DRAIN_PER_SECOND, GameConfig.FUEL_GRACE_SECONDS)
				run.configure_track(track)
				run.configure_difficulty(DifficultyProfile.for_index(difficulty_index))
				run.start()
				for _step in range(400):
					var speed_before_step := drive.speed
					drive.step(0.25, 1.0, 0.0)
					var forward_acceleration := maxf(0.0, (drive.speed - speed_before_step) / 0.25)
					run.tick(0.25, drive.speed, drive.max_speed, forward_acceleration)
					if run.phase != RunState.Phase.RUNNING:
						break
				assert(run.phase == RunState.Phase.RUN_CLEAR, "%s must accelerate and finish %s on difficulty %d" % [vehicle.id, track.id, difficulty_index])
				assert(run.fuel >= 5.0, "%s acceleration cost must preserve a finish margin on %s difficulty %d: %.2f" % [vehicle.id, track.id, difficulty_index, run.fuel])
