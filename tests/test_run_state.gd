extends SceneTree

const RunState = preload("res://scripts/run_state.gd")

func _init() -> void:
	for seed in range(10):
		var run := RunState.new(100.0, 4.0, 30.0)
		run.start()
		for _second in range(120):
			run.tick(1.0, 320.0 + seed * 20.0, 760.0)
			if run.phase == RunState.Phase.ENDED:
				break
		assert(run.distance > 0.0, "Each regression run must accumulate distance")
		assert(run.score > 0, "Each regression run must earn distance score")

	var protected_run := RunState.new(1.0, 4.0, 30.0)
	protected_run.start()
	protected_run.tick(29.9, 760.0, 760.0)
	assert(protected_run.phase == RunState.Phase.RUNNING, "Fuel may not end a run during its first 30 seconds")
	protected_run.tick(0.2, 760.0, 760.0)
	assert(protected_run.phase == RunState.Phase.ENDED, "An empty tank must end the run after the grace period")

	var stages := RunState.new(100.0, 0.0, 30.0)
	stages.start()
	stages.tick(30.0, 500.0, 760.0)
	assert(stages.difficulty_stage == 0, "The first 30 seconds must retain the stage-zero traffic rules")
	stages.tick(5.0, 500.0, 760.0)
	assert(stages.difficulty_stage == 1, "Stage one must begin after the protected opening")
	stages.tick(40.0, 500.0, 760.0)
	assert(stages.difficulty_stage == 2, "Stage two must introduce the full traffic set")
	stages.tick(40.0, 500.0, 760.0)
	assert(stages.difficulty_stage == 3, "Stage three must preserve the late-run escalation")

	var paused_run := RunState.new(100.0, 4.0, 30.0)
	paused_run.start()
	paused_run.tick(2.0, 600.0, 760.0)
	var distance_before_pause := paused_run.distance
	paused_run.toggle_pause()
	paused_run.tick(2.0, 760.0, 760.0)
	assert(is_equal_approx(paused_run.distance, distance_before_pause), "Pause must freeze run progress")
	paused_run.toggle_pause()
	paused_run.tick(3.0, 0.0, 760.0)
	paused_run.add_fuel(25.0)
	paused_run.award_overtake(75)
	assert(paused_run.fuel > 90.0 and paused_run.score > 75, "Fuel pickups and overtakes must reward an active run")
	paused_run.reset()
	assert(paused_run.phase == RunState.Phase.READY and is_zero_approx(paused_run.distance) and paused_run.score == 0 and is_equal_approx(paused_run.fuel, 100.0), "Reset must clear all per-run state")
	quit()
