extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RunSeedSequence = preload("res://scripts/run_seed_sequence.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var sequence_a := RunSeedSequence.new(12345)
	var sequence_b := RunSeedSequence.new(12345)
	var first_seed := sequence_a.next_seed()
	var second_seed := sequence_a.next_seed()
	assert(first_seed != second_seed, "Consecutive runs must receive different seeds")
	assert(first_seed == sequence_b.next_seed() and second_seed == sequence_b.next_seed(), "A fixed sequence seed must reproduce run seeds")

	var traffic := TrafficDirector.new(41)
	for _second in range(30):
		traffic.tick(1.0, 500.0, 1)
	var first_traffic_sequence := traffic.spawn_sequence()
	traffic.reset(41)
	for _second in range(30):
		traffic.tick(1.0, 500.0, 1)
	assert(traffic.spawn_sequence() == first_traffic_sequence, "An explicit run seed must reproduce traffic")
	traffic.reset(42)
	for _second in range(30):
		traffic.tick(1.0, 500.0, 1)
	assert(traffic.spawn_sequence() != first_traffic_sequence, "Different run seeds must vary traffic")

	var main = MainScene.instantiate()
	root.add_child(main)
	main.run_seed_sequence = RunSeedSequence.new(9001)
	main._reset_run()
	var first_main_seed: int = main.current_run_seed
	main._reset_run()
	assert(main.current_run_seed != first_main_seed, "Normal restarts must advance to a new run seed")
	main._reset_run(first_main_seed)
	assert(main.current_run_seed == first_main_seed, "A reported run seed must be accepted for reproduction")
	await _teardown_audio_main(main)
	quit()

func _teardown_audio_main(main: Node) -> void:
	main._stop_run_audio()
	for player in [main.collision_audio, main.engine_audio, main.acceleration_audio, main.pickup_audio, main.warning_audio]:
		player.stream = null
	main.queue_free()
	await process_frame
	await process_frame
	await process_frame
