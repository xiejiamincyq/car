class_name TourProgress
extends RefCounted

const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")

const STARTER_VEHICLES := [&"pulse_gt", &"driftwing", &"flashpoint"]
const FIRST_CLEAR_VEHICLE := &"comet_rs"
const FOUR_MEDAL_VEHICLE := &"tidebreaker"
const ALL_CLEAR_VEHICLE := &"aurora_x"

static func default_data() -> Dictionary:
	var track_results := {}
	for track in TrackCatalog.all():
		track_results[track.id] = {
			"cleared": false,
			"best_score": 0,
			"best_time": 0.0,
			"medal": 0,
		}
	return {
		"selected_track_id": &"neon_coast",
		"selected_vehicle_id": &"pulse_gt",
		"track_results": track_results,
	}

static func is_track_unlocked(progress: Dictionary, track_id: StringName) -> bool:
	var tracks := TrackCatalog.all()
	for index in tracks.size():
		if tracks[index].id != track_id:
			continue
		if index == 0:
			return true
		var previous_result := _track_result(progress, tracks[index - 1].id)
		return bool(previous_result.get("cleared", false))
	return false

static func is_vehicle_unlocked(progress: Dictionary, vehicle_id: StringName) -> bool:
	if VehicleCatalog.get_by_id(vehicle_id).is_empty():
		return false
	if vehicle_id in STARTER_VEHICLES:
		return true
	if vehicle_id == FIRST_CLEAR_VEHICLE:
		return clear_count(progress) >= 1
	if vehicle_id == FOUR_MEDAL_VEHICLE:
		return total_medals(progress) >= 4
	if vehicle_id == ALL_CLEAR_VEHICLE:
		return clear_count(progress) >= TrackCatalog.all().size()
	return false

static func select_track(progress: Dictionary, track_id: StringName) -> bool:
	if not is_track_unlocked(progress, track_id):
		return false
	progress.selected_track_id = track_id
	return true

static func select_vehicle(progress: Dictionary, vehicle_id: StringName) -> bool:
	if not is_vehicle_unlocked(progress, vehicle_id):
		return false
	progress.selected_vehicle_id = vehicle_id
	return true

static func record_result(progress: Dictionary, track_id: StringName, score: int, elapsed_seconds: float, cleared: bool, medal: int) -> Dictionary:
	if TrackCatalog.get_by_id(track_id).is_empty():
		return progress.duplicate(true)
	var updated := progress.duplicate(true)
	if not updated.has("track_results") or not updated.track_results is Dictionary:
		updated.track_results = default_data().track_results
	var previous := _track_result(updated, track_id)
	var best_time := float(previous.get("best_time", 0.0))
	if cleared and elapsed_seconds > 0.0 and (is_zero_approx(best_time) or elapsed_seconds < best_time):
		best_time = elapsed_seconds
	updated.track_results[track_id] = {
		"cleared": bool(previous.get("cleared", false)) or cleared,
		"best_score": maxi(int(previous.get("best_score", 0)), maxi(0, score)),
		"best_time": best_time,
		"medal": maxi(int(previous.get("medal", 0)), clampi(medal, 0, 3)),
	}
	return updated

static func total_medals(progress: Dictionary) -> int:
	var total := 0
	for track in TrackCatalog.all():
		total += int(_track_result(progress, track.id).get("medal", 0))
	return total

static func clear_count(progress: Dictionary) -> int:
	var total := 0
	for track in TrackCatalog.all():
		if bool(_track_result(progress, track.id).get("cleared", false)):
			total += 1
	return total

static func _track_result(progress: Dictionary, track_id: StringName) -> Dictionary:
	var results = progress.get("track_results", {})
	if results is Dictionary and results.has(track_id) and results[track_id] is Dictionary:
		return results[track_id]
	return {}
