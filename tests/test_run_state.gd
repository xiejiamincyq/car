extends SceneTree

const GameConfig = preload("res://scripts/game_config.gd")
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
	protected_run.tick(29.9, 0.0, 760.0, GameConfig.ACCELERATION)
	assert(protected_run.phase == RunState.Phase.RUNNING, "Fuel may not end a run during its first 30 seconds")
	protected_run.tick(0.2, 0.0, 760.0, GameConfig.ACCELERATION)
	assert(protected_run.phase == RunState.Phase.ENDED, "An empty tank must end the run after the grace period")

	var coasting := RunState.new(100.0, 4.0, 0.0)
	var accelerating := RunState.new(100.0, 4.0, 0.0)
	coasting.start()
	accelerating.start()
	coasting.tick(1.0, 560.0, 760.0, 0.0)
	accelerating.tick(1.0, 560.0, 760.0, GameConfig.ACCELERATION)
	var coasting_drain := 100.0 - coasting.fuel
	var accelerating_drain := 100.0 - accelerating.fuel
	assert(coasting_drain > 0.0, "A moving vehicle must consume fuel against rolling and aerodynamic resistance")
	assert(accelerating_drain > coasting_drain * 2.0, "Positive acceleration must add a meaningful fuel cost on top of resistance")
	var low_speed_acceleration := RunState.new(100.0, 4.0, 0.0)
	var high_speed_acceleration := RunState.new(100.0, 4.0, 0.0)
	low_speed_acceleration.start()
	high_speed_acceleration.start()
	low_speed_acceleration.tick(1.0, 280.0, 760.0, GameConfig.ACCELERATION)
	high_speed_acceleration.tick(1.0, 760.0, 760.0, GameConfig.ACCELERATION)
	assert(high_speed_acceleration.fuel < low_speed_acceleration.fuel, "Equal positive acceleration must consume more fuel at higher speed because resistance is greater")

	var stages := RunState.new(100.0, 0.0, 30.0)
	stages.start()
	stages.tick(15.9, 500.0, 760.0)
	assert(stages.difficulty_stage == 0, "The opening traffic rules must remain active before 800m")
	stages.tick(0.1, 500.0, 760.0)
	assert(stages.difficulty_stage == 1, "Stage one must begin at the 800m checkpoint")
	stages.tick(16.0, 500.0, 760.0)
	assert(stages.difficulty_stage == 2, "Stage two must begin at the 1600m checkpoint")
	stages.tick(16.0, 500.0, 760.0)
	assert(stages.difficulty_stage == 3, "Stage three must begin at the 2400m checkpoint")

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
	var score_before_coin := paused_run.score
	var coin_score: int = paused_run.award_coin(20)
	assert(coin_score == 20 and paused_run.coins == 1 and paused_run.score == score_before_coin + 20, "The first coin must add one count, twenty immediate points, and extend the shared combo")
	var fuel_before_overdrive_cost: float = paused_run.fuel
	paused_run.consume_fuel(10.0)
	assert(is_equal_approx(paused_run.fuel, fuel_before_overdrive_cost - 10.0), "An active run must accept explicit gradual overdrive fuel costs")
	paused_run.toggle_pause()
	var paused_fuel: float = paused_run.fuel
	paused_run.consume_fuel(10.0)
	assert(is_equal_approx(paused_run.fuel, paused_fuel), "Paused gameplay must not consume overdrive fuel")
	assert(paused_run.award_coin(20) == 0 and paused_run.coins == 1, "Paused gameplay must not settle coins")
	paused_run.reset()
	assert(paused_run.phase == RunState.Phase.READY and is_zero_approx(paused_run.distance) and paused_run.score == 0 and paused_run.coins == 0 and is_equal_approx(paused_run.fuel, 100.0), "Reset must clear all per-run state")
	quit()
