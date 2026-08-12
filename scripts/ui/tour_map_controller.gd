class_name TourMapController
extends RefCounted

const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const TourProgress = preload("res://scripts/catalog/tour_progress.gd")

var progress: Dictionary
var selected_index := 0

func _init(initial_progress: Dictionary) -> void:
	set_progress(initial_progress)

func set_progress(updated_progress: Dictionary) -> void:
	progress = updated_progress
	var tracks := TrackCatalog.all()
	selected_index = 0
	for index in tracks.size():
		if tracks[index].id == progress.get("selected_track_id", &""):
			selected_index = index
			break

func move(direction: int) -> void:
	selected_index = clampi(selected_index + direction, 0, TrackCatalog.all().size() - 1)

func selected_track_id() -> StringName:
	return TrackCatalog.all()[selected_index].id

func can_confirm() -> bool:
	return TourProgress.is_track_unlocked(progress, selected_track_id())

func confirm() -> bool:
	return TourProgress.select_track(progress, selected_track_id())

func node_states() -> Array:
	var states := []
	for index in TrackCatalog.all().size():
		var track: Dictionary = TrackCatalog.all()[index]
		states.append({
			"id": track.id,
			"name_key": track.name_key,
			"unlocked": TourProgress.is_track_unlocked(progress, track.id),
			"selected": index == selected_index,
			"result": progress.track_results.get(track.id, {}).duplicate(true),
		})
	return states
