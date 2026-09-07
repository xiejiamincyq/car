class_name Progression
extends RefCounted

const TourProgress = preload("res://scripts/catalog/tour_progress.gd")
const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const RunRating = preload("res://scripts/run_rating.gd")

static func record_run(current_data: Dictionary, result: Dictionary, date: String) -> Dictionary:
	var data := current_data.duplicate(true)
	var new_entry := {
		"score": maxi(0, int(result.score)),
		"difficulty": clampi(int(result.difficulty), 0, 2),
		"distance": maxf(0.0, float(result.distance)),
		"date": date,
	}
	var rank := 1
	for existing in data.top_scores:
		if not _comes_before(new_entry, existing):
			rank += 1
	data.top_scores.append(new_entry)
	data.top_scores.sort_custom(_comes_before)
	if data.top_scores.size() > 5:
		data.top_scores.resize(5)
	if rank > 5:
		rank = 0

	data.career.runs += 1
	data.career.total_distance += maxf(0.0, float(result.distance))
	data.career.overtakes += maxi(0, int(result.overtakes))
	data.career.near_misses += maxi(0, int(result.near_misses))
	data.career.longest_survival = maxf(data.career.longest_survival, maxf(0.0, float(result.survival)))
	data.career.highest_stage = maxi(data.career.highest_stage, maxi(0, int(result.stage)))
	if result.has("track_id") and result.track_id is StringName:
		data.tour = TourProgress.record_result(
			data.tour,
			result.track_id,
			maxi(0, int(result.score)),
			maxf(0.0, float(result.survival)),
			bool(result.get("cleared", false)),
			clampi(int(result.get("medal", 0)), 0, 3)
		)
	var rating := {}
	var new_rating_record := false
	if result.get("track_id") is StringName:
		var track := TrackCatalog.get_by_id(result.track_id)
		rating = RunRating.evaluate(result, track.get("rating_targets", {}))
		if not rating.is_empty():
			var best: Dictionary = data.ratings.get(result.track_id, {})
			if best.is_empty() or int(rating.total) > int(best.total):
				data.ratings[result.track_id] = {"total": rating.total, "grade": rating.grade}
				new_rating_record = true
	return {"data": data, "new_record": rank == 1, "rank": rank, "rating": rating, "new_rating_record": new_rating_record}

static func _comes_before(left: Dictionary, right: Dictionary) -> bool:
	if left.score != right.score:
		return left.score > right.score
	if left.difficulty != right.difficulty:
		return left.difficulty > right.difficulty
	if not is_equal_approx(left.distance, right.distance):
		return left.distance > right.distance
	return left.date > right.date
