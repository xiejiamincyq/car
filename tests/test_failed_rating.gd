extends SceneTree

const Rating = preload("res://scripts/run_rating.gd")

func _init() -> void:
	var targets := {"time": 60.0, "overtakes": 10, "coins": 60}
	var run := {"cleared": false, "survival": 30.0, "distance": 500.0, "finish_distance": 1000.0, "overtakes": 5, "coins": 30, "collisions": 0}
	var half := Rating.evaluate(run, targets)
	assert(not half.is_empty(), "Unfinished runs must receive a progress-based rating")
	assert(half.total == 49 and half.parts.values().reduce(func(a, b): return a + b, 0) == 49, "Capped component scores must add up to the displayed total")
	for progress in [0.0, 0.25, 0.5, 0.99]:
		run.distance = 1000.0 * progress
		run.survival = 60.0 * progress
		var rated := Rating.evaluate(run, targets)
		assert(not rated.is_empty() and rated.total <= floori(99 * progress))
		assert(rated == Rating.evaluate(run, targets), "Rating must be deterministic")
		for reason in [&"fuel", &"integrity", &"timeout"]:
			run.failure_reason = reason
			assert(Rating.evaluate(run, targets) == rated, "Failure reason must not erase earned performance")
	run.distance = 500.0
	run.survival = 30.0
	run.overtakes = 10000
	run.coins = 10000
	assert(Rating.evaluate(run, targets).total <= 49, "Farming must not bypass the progress cap")
	run.survival = 90.0
	assert(Rating.evaluate(run, targets).parts.time == 0, "Idling must not improve pace points")
	for invalid in [NAN, INF, -1.0]:
		run.distance = invalid
		assert(Rating.evaluate(run, targets).is_empty())
	run.distance = 500.0
	run.finish_distance = 0.0
	assert(Rating.evaluate(run, targets).is_empty())
	quit()
