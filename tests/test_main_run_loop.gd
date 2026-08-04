extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const Main = preload("res://scripts/main.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(Main.is_eligible_overtake(TrafficDirector.Kind.STEADY_SLOW, true, false), "A normal vehicle that truly passes must score")
	assert(not Main.is_eligible_overtake(TrafficDirector.Kind.FAST_OVERTAKE, true, false), "Rear overtakers must never earn a front-pass reward")
	assert(not Main.is_eligible_overtake(TrafficDirector.Kind.STEADY_SLOW, false, false), "A vehicle must be observed ahead before it can score")
	assert(not Main.is_eligible_overtake(TrafficDirector.Kind.STEADY_SLOW, true, true), "A collision-displaced vehicle must not score")
	var main = MainScene.instantiate()
	root.add_child(main)
	main.run.start()
	main.run.elapsed_seconds = 29.9
	main.run.fuel = 0.0
	main.collision.invulnerability_remaining = 0.5
	main._process(0.2)
	assert(main.run.phase == main.RunState.Phase.ENDED, "The fuel-ending frame must enter settlement immediately")
	assert(main.traffic.vehicles.is_empty(), "Traffic may not advance or spawn after the ending transition")
	assert(main.fuel_pickups.is_empty(), "Pickups may not advance or spawn after the ending transition")
	assert(is_equal_approx(main.collision.invulnerability_remaining, 0.5), "Collision timers may not advance after the ending transition")
	main.free()

	var cleared_main = MainScene.instantiate()
	root.add_child(cleared_main)
	cleared_main.run.start()
	cleared_main.run.distance = cleared_main.GameConfig.RACE_FINISH_DISTANCE - 1.0
	cleared_main.collision.invulnerability_remaining = 0.5
	cleared_main._process(0.1)
	assert(cleared_main.run.phase == cleared_main.RunState.Phase.RUN_CLEAR, "The finish frame must enter settlement immediately")
	assert(cleared_main.traffic.vehicles.is_empty(), "Traffic may not advance or spawn after the clear transition")
	assert(is_equal_approx(cleared_main.collision.invulnerability_remaining, 0.5), "Collision timers may not advance after the clear transition")
	cleared_main.free()
	quit()
