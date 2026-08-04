extends SceneTree

const ComboTracker = preload("res://scripts/combo_tracker.gd")
const RunState = preload("res://scripts/run_state.gd")

func _init() -> void:
	var combo := ComboTracker.new(2.5, 3, 4)
	assert(combo.award(100) == 100 and combo.multiplier == 1, "The first event must use the base score")
	combo.award(100)
	combo.award(100)
	assert(combo.award(100) == 200 and combo.multiplier == 2, "Four events inside the window must reach x2")
	for _event in range(20):
		combo.award(100)
	assert(combo.multiplier == 3 and combo.award(100) == 300, "The multiplier must respect its configured cap")
	combo.tick(2.49)
	assert(combo.multiplier == 3 and combo.remaining_seconds > 0.0, "The combo must survive just inside its window")
	combo.tick(0.02)
	assert(combo.multiplier == 1 and combo.event_count == 0 and is_zero_approx(combo.remaining_seconds), "Timeout must clear the combo")

	var run := RunState.new(100.0, 0.0, 30.0)
	run.start()
	for _event in range(4):
		run.award_pass(100, false)
	assert(run.combo.multiplier == 2, "Run scoring must use the combo tracker")
	run.toggle_pause()
	run.tick(10.0, 0.0, 760.0)
	assert(run.combo.multiplier == 2, "Pause must freeze the combo window")
	run.break_combo()
	assert(run.combo.multiplier == 1 and run.combo.event_count == 0, "Collision must clear the combo")

	var inflation_ratios: Array[float] = []
	for seed in range(20):
		inflation_ratios.append(_simulate_score_ratio(seed))
	inflation_ratios.sort()
	var median_ratio := inflation_ratios[inflation_ratios.size() / 2]
	assert(median_ratio <= 1.20, "The fixed-seed 300-second median score inflation must stay within 20 percent")
	quit()

func _simulate_score_ratio(seed: int) -> float:
	var combo := ComboTracker.new(2.5, 3, 4)
	var baseline := 0
	var enhanced := 0
	var elapsed := 0.0
	var event_index := 0
	while elapsed < 300.0:
		var gap := 2.2 + float((seed * 11 + event_index * 7) % 6) * 0.55
		combo.tick(gap)
		elapsed += gap
		if elapsed > 300.0:
			break
		var base_points := 200 if (seed + event_index) % 7 == 0 else 80
		baseline += base_points
		enhanced += combo.award(base_points)
		event_index += 1
	return float(enhanced) / float(maxi(1, baseline))
