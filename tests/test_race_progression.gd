extends SceneTree

const RaceProgression = preload("res://scripts/race_progression.gd")
const RunState = preload("res://scripts/run_state.gd")

func _init() -> void:
	var progression := RaceProgression.new([800.0, 1600.0, 2400.0], 3200.0)
	var opening := progression.observe(799.99)
	assert(opening.stage == 0 and opening.checkpoints_crossed == 0 and not opening.cleared, "The opening stage must remain active before 800m")
	var first := progression.observe(800.0)
	assert(first.stage == 1 and first.checkpoints_crossed == 1, "The exact checkpoint boundary must advance once")
	var repeated := progression.observe(800.0)
	assert(repeated.checkpoints_crossed == 0 and repeated.stage == 1, "Re-observing a checkpoint must not duplicate its reward")
	var jump := progression.observe(2500.0)
	assert(jump.stage == 3 and jump.checkpoints_crossed == 2, "A large distance step must not skip intermediate checkpoints")
	var finish := progression.observe(3200.0)
	assert(finish.cleared and finish.stage == 3, "The exact finish boundary must clear the run")
	assert(not progression.observe(4000.0).cleared, "Run clear may only be emitted once")
	progression.reset()
	assert(progression.observe(800.0).checkpoints_crossed == 1, "Reset must make every checkpoint available for a new run")

	var run := RunState.new(100.0, 0.0, 30.0)
	run.start()
	run.fuel = 40.0
	run.tick(16.0, 500.0, 760.0)
	assert(run.difficulty_stage == 1 and is_equal_approx(run.fuel, 52.0), "RunState must grant one configured fuel reward at the first checkpoint")
	run.tick(0.0, 500.0, 760.0)
	assert(is_equal_approx(run.fuel, 52.0), "A stationary checkpoint frame must not reward fuel twice")
	run.break_combo()
	run.tick(0.0, 500.0, 760.0)
	assert(is_equal_approx(run.fuel, 52.0), "Breaking a combo must not reset race checkpoints or duplicate fuel rewards")
	run.tick(48.0, 500.0, 760.0)
	assert(run.phase == RunState.Phase.RUN_CLEAR and is_equal_approx(run.distance, 3200.0), "Reaching the configured finish must enter RUN_CLEAR")
	run.reset()
	run.start()
	run.fuel = 40.0
	run.tick(16.0, 500.0, 760.0)
	assert(run.difficulty_stage == 1 and is_equal_approx(run.fuel, 52.0), "Reset must restore checkpoint rewards for the next run")
	quit()
