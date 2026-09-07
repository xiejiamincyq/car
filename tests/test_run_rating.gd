extends SceneTree

const Rating = preload("res://scripts/run_rating.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")

func _init() -> void:
	var targets := {"time": 60.0, "overtakes": 10, "coins": 60}
	var run := {"cleared": true, "survival": 60.0, "overtakes": 10, "coins": 60, "collisions": 0}
	var perfect := Rating.evaluate(run, targets)
	assert(perfect.total == 100 and perfect.grade == "S")
	assert(perfect.parts == {"time": 40, "overtakes": 20, "collisions": 20, "coins": 20})
	run.survival = 90.0
	run.overtakes = 5
	run.coins = 30
	run.collisions = 2
	assert(Rating.evaluate(run, targets).total == 52, "Each component must use its own weight")
	run.survival = 200.0
	run.overtakes = 0
	run.coins = 0
	run.collisions = 6
	assert(Rating.evaluate(run, targets).total == 0)
	run.cleared = false
	assert(Rating.evaluate(run, targets).is_empty(), "Failures have no formal rating")
	run.cleared = true
	for invalid in [0.0, -1.0, NAN, INF]:
		run.survival = invalid
		assert(Rating.evaluate(run, targets).is_empty(), "Invalid time must not award points")
	run.survival = 1.0
	run.coins = 100000
	run.overtakes = 100000
	run.collisions = 0
	assert(Rating.evaluate(run, targets).total == 100, "Components must cap at their weights")
	assert(Rating.evaluate(run, {}).is_empty())
	for points in range(101):
		var expected := "S" if points >= 90 else "A" if points >= 80 else "B" if points >= 70 else "C" if points >= 60 else "D"
		assert(Rating.grade_for(points) == expected)
	for track in Tracks.all():
		assert(Rating.valid_targets(track.rating_targets), "Every track needs usable rating targets")
	quit()
