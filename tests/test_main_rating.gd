extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/save_store.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	main._configure_persistence(SaveStore.new("user://test_rating_unused.cfg"), false)
	main.save_data = SaveStore.default_data()
	main._reset_run(611)
	main.run.phase = main.RunState.Phase.RUN_CLEAR
	main.run.elapsed_seconds = main.TrackCatalog.get_by_id(&"neon_coast").rating_targets.time
	main.run.overtakes = 12
	main.run.coins = 27
	main.coin_director.generated_coin_count = 60
	main.run.collisions = 2
	main._persist_result_once()
	assert(main.last_run_rating.total == 82, "Settlement must use the actual coin and collision counters")
	assert(main.save_data.ratings.neon_coast.total == 82)
	var snapshot: Dictionary = main.save_data.duplicate(true)
	main._persist_result_once()
	assert(main.save_data == snapshot, "Repeated settlement must not double-count the run")
	main._reset_run(612)
	assert(main.last_run_rating.is_empty(), "Restart must clear the previous rating")
	main.run.phase = main.RunState.Phase.GAME_OVER
	main.run.elapsed_seconds = 60.0
	main.run.distance = main.run.progression.finish_distance * 0.5
	main._persist_result_once()
	assert(not main.last_run_rating.is_empty() and main.last_run_rating.total <= 49)
	assert(main.save_data.ratings.neon_coast.total == 82)
	var refs := AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	assert(await AudioTeardown.wait_for_release(self, refs))
	quit()
