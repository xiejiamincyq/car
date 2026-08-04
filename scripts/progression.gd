class_name Progression
extends RefCounted

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
	return {"data": data, "new_record": rank == 1, "rank": rank}

static func _comes_before(left: Dictionary, right: Dictionary) -> bool:
	if left.score != right.score:
		return left.score > right.score
	if left.difficulty != right.difficulty:
		return left.difficulty > right.difficulty
	if not is_equal_approx(left.distance, right.distance):
		return left.distance > right.distance
	return left.date > right.date
