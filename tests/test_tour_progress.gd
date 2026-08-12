extends SceneTree

const TourProgress = preload("res://scripts/catalog/tour_progress.gd")

func _init() -> void:
	_assert_fresh_progress()
	_assert_linear_track_unlocks()
	_assert_vehicle_unlocks()
	_assert_selection_fails_closed()
	quit()

func _assert_fresh_progress() -> void:
	var progress := TourProgress.default_data()
	assert(progress.selected_track_id == &"neon_coast", "Fresh progress must select the teaching track")
	assert(progress.selected_vehicle_id == &"pulse_gt", "Fresh progress must select the balanced vehicle")
	assert(TourProgress.is_track_unlocked(progress, &"neon_coast"), "The first track must start unlocked")
	assert(not TourProgress.is_track_unlocked(progress, &"freight_harbor"), "Later tracks must start locked")
	for vehicle_id in [&"pulse_gt", &"driftwing", &"flashpoint"]:
		assert(TourProgress.is_vehicle_unlocked(progress, vehicle_id), "Three starter vehicles must be available")

func _assert_linear_track_unlocks() -> void:
	var progress := TourProgress.default_data()
	progress = TourProgress.record_result(progress, &"neon_coast", 5400, 205.0, true, 1)
	assert(TourProgress.is_track_unlocked(progress, &"freight_harbor"), "Clearing the coast must unlock the harbor")
	assert(not TourProgress.is_track_unlocked(progress, &"storm_ridge"), "Tracks must not skip the linear route")
	progress = TourProgress.record_result(progress, &"freight_harbor", 6100, 220.0, true, 1)
	assert(TourProgress.is_track_unlocked(progress, &"storm_ridge"), "Clearing the harbor must unlock the ridge")
	progress = TourProgress.record_result(progress, &"storm_ridge", 6500, 230.0, true, 1)
	assert(TourProgress.is_track_unlocked(progress, &"sunrise_express"), "Clearing the ridge must unlock the final highway")

func _assert_vehicle_unlocks() -> void:
	var progress := TourProgress.default_data()
	progress = TourProgress.record_result(progress, &"neon_coast", 5400, 205.0, true, 1)
	assert(TourProgress.is_vehicle_unlocked(progress, &"comet_rs"), "The speed vehicle must unlock after the first clear")
	assert(not TourProgress.is_vehicle_unlocked(progress, &"tidebreaker"), "The stable vehicle must require four medals")
	for track_id in [&"neon_coast", &"freight_harbor", &"storm_ridge", &"sunrise_express"]:
		progress = TourProgress.record_result(progress, track_id, 7000, 210.0, true, 1)
	assert(TourProgress.total_medals(progress) >= 4, "Four bronze-or-better track medals must count toward the garage")
	assert(TourProgress.is_vehicle_unlocked(progress, &"tidebreaker"), "The stable vehicle must unlock at four medals")
	assert(TourProgress.is_vehicle_unlocked(progress, &"aurora_x"), "The expert vehicle must unlock after all four clears")

func _assert_selection_fails_closed() -> void:
	var progress := TourProgress.default_data()
	var unchanged := progress.duplicate(true)
	assert(not TourProgress.select_track(progress, &"storm_ridge"), "Locked tracks must not be selectable")
	assert(progress == unchanged, "Rejected track selection must not mutate progress")
	assert(not TourProgress.select_vehicle(progress, &"aurora_x"), "Locked vehicles must not be selectable")
	assert(progress == unchanged, "Rejected vehicle selection must not mutate progress")
	assert(not TourProgress.select_track(progress, &"missing"), "Unknown track IDs must fail closed")
	assert(not TourProgress.select_vehicle(progress, &"missing"), "Unknown vehicle IDs must fail closed")
	assert(TourProgress.select_track(progress, &"neon_coast"), "Unlocked tracks must be selectable")
	assert(TourProgress.select_vehicle(progress, &"driftwing"), "Unlocked starter vehicles must be selectable")
