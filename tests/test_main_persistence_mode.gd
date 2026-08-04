extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	var main = current_scene
	assert(main != null and main.persistence_enabled, "The real main-scene lifecycle must enable player persistence")
	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	await process_frame
	quit()
