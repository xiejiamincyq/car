extends SceneTree

const SaveStore = preload("res://scripts/save_store.gd")
const Progression = preload("res://scripts/progression.gd")

func _init() -> void:
	var data := SaveStore.default_data()
	var first := Progression.record_run(data, _result(100, 1, 600.0, 25.0, 2, 1, 3), "2026-08-01")
	assert(first.new_record and first.rank == 1, "The first score must be a new record")
	data = first.data
	assert(data.career.runs == 1 and is_equal_approx(data.career.total_distance, 600.0), "A settled run must update career totals")
	assert(data.career.overtakes == 2 and data.career.near_misses == 1 and is_equal_approx(data.career.longest_survival, 25.0) and data.career.highest_stage == 3, "Career maxima and counters must update together")

	for entry in [
		_result(100, 2, 500.0, 20.0, 0, 0, 2),
		_result(100, 2, 700.0, 20.0, 0, 0, 2),
		_result(900, 0, 300.0, 20.0, 0, 0, 1),
		_result(50, 2, 900.0, 20.0, 0, 0, 4),
		_result(25, 1, 100.0, 20.0, 0, 0, 1),
	]:
		data = Progression.record_run(data, entry, "2026-08-02").data
	assert(data.top_scores.size() == 5, "The leaderboard must retain only five entries")
	assert(data.top_scores[0].score == 900, "Score must be the primary ranking key")
	assert(data.top_scores[1].difficulty == 2 and is_equal_approx(data.top_scores[1].distance, 700.0), "Difficulty then distance must break equal-score ties")
	assert(data.top_scores[4].score == 50, "Scores below the top five must be discarded")

	var lower := Progression.record_run(data, _result(1, 0, 1.0, 1.0, 0, 0, 0), "2026-08-03")
	assert(not lower.new_record and lower.rank == 0, "A score outside the leaderboard must not report a rank")
	var tour_result := _result(6200, 1, 3200.0, 198.5, 12, 3, 4)
	tour_result.track_id = &"neon_coast"
	tour_result.cleared = true
	tour_result.medal = 2
	var toured := Progression.record_run(data, tour_result, "2026-08-04")
	assert(toured.data.tour.track_results.neon_coast.cleared, "A cleared run must update the selected track progress")
	assert(toured.data.tour.track_results.neon_coast.best_score == 6200 and toured.data.tour.track_results.neon_coast.medal == 2, "A settled tour result must retain its score and medal")
	quit()

func _result(score: int, difficulty: int, distance: float, survival: float, overtakes: int, near_misses: int, stage: int) -> Dictionary:
	return {
		"score": score,
		"difficulty": difficulty,
		"distance": distance,
		"survival": survival,
		"overtakes": overtakes,
		"near_misses": near_misses,
		"stage": stage,
	}
