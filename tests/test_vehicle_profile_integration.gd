extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	for vehicle in VehicleCatalog.all():
		main.save_data.tour.selected_vehicle_id = vehicle.id
		main._start_new_run()
		assert(main.current_vehicle.id == vehicle.id, "The active profile must follow the garage selection")
		assert(is_equal_approx(main.drive.max_speed, vehicle.max_speed), "%s max speed must reach the controller" % vehicle.id)
		assert(is_equal_approx(main.drive.acceleration, vehicle.acceleration), "%s acceleration must reach the controller" % vehicle.id)
		assert(is_equal_approx(main.drive.braking, vehicle.braking), "%s braking must reach the controller" % vehicle.id)
		assert(is_equal_approx(main.drive.steering_speed, vehicle.steering_speed), "%s steering must reach the controller" % vehicle.id)
		assert(is_equal_approx(main.collision.speed_penalty, vehicle.collision_speed_penalty), "%s collision loss must reach the responder" % vehicle.id)
		assert(main.current_player_texture.resource_path == String(vehicle.texture_path), "%s must render its own sprite" % vehicle.id)
		main.drive.speed = vehicle.max_speed
		var hit = main.collision.try_collide(main.drive.speed)
		assert(is_equal_approx(hit.speed, vehicle.max_speed - vehicle.collision_speed_penalty), "%s collision must apply its profile penalty" % vehicle.id)
	main.save_data.tour.selected_vehicle_id = &"driftwing"
	main._start_new_run()
	main._restart_run()
	assert(main.current_vehicle.id == &"driftwing" and is_equal_approx(main.drive.steering_speed, VehicleCatalog.get_by_id(&"driftwing").steering_speed), "Restart must retain the selected vehicle")
	main.audio_director.stop_run_audio()
	for player in [main.audio_director.collision_audio, main.audio_director.engine_audio, main.audio_director.acceleration_audio, main.audio_director.pickup_audio, main.audio_director.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	await process_frame
	quit()
