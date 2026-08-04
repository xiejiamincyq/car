extends SceneTree

const RunState = preload("res://scripts/run_state.gd")

func _init() -> void:
	var run := RunState.new(100.0, 4.0, 30.0)
	assert(run.phase == RunState.Phase.TITLE, "A fresh game must open on the title screen")
	run.begin_countdown(3.0)
	assert(run.phase == RunState.Phase.COUNTDOWN and is_equal_approx(run.countdown_remaining, 3.0), "Starting from title must enter countdown")
	var initial_fuel := run.fuel
	run.tick(1.0, 760.0, 760.0)
	assert(run.phase == RunState.Phase.COUNTDOWN and is_zero_approx(run.distance), "Countdown must freeze run progress")
	assert(is_equal_approx(run.fuel, initial_fuel), "Countdown must not consume fuel")
	run.tick(2.0, 760.0, 760.0)
	assert(run.phase == RunState.Phase.RUNNING, "Countdown completion must start the run")

	run.toggle_pause()
	assert(run.phase == RunState.Phase.PAUSED, "Pause must stop a running game")
	var distance_before_pause := run.distance
	run.tick(2.0, 760.0, 760.0)
	assert(is_equal_approx(run.distance, distance_before_pause), "Pause must freeze progress")
	run.toggle_pause()
	assert(run.phase == RunState.Phase.COUNTDOWN, "Resuming from pause must use a safety countdown")
	run.tick(3.0, 760.0, 760.0)
	assert(run.phase == RunState.Phase.RUNNING, "Resume countdown must return to the same run")

	run.end()
	assert(run.phase == RunState.Phase.GAME_OVER, "Fuel or forced ending must use the game-over result state")
	run.return_to_title()
	assert(run.phase == RunState.Phase.TITLE, "Result screens must be able to return to title")
	run.toggle_pause()
	assert(run.phase == RunState.Phase.TITLE, "Title cannot be paused")

	run.start()
	run.mark_clear()
	assert(run.phase == RunState.Phase.RUN_CLEAR, "A completed route must have a distinct clear result state")
	run.reset()
	assert(run.phase == RunState.Phase.TITLE and is_zero_approx(run.distance) and run.score == 0, "Reset must return to a clean title state")
	quit()
