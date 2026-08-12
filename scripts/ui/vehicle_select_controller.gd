class_name VehicleSelectController
extends RefCounted

const TourProgress = preload("res://scripts/catalog/tour_progress.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")

const UNLOCK_KEYS := {
	&"comet_rs": &"unlock_first_clear",
	&"tidebreaker": &"unlock_four_medals",
	&"aurora_x": &"unlock_all_tracks",
}

var progress: Dictionary
var selected_index := 0

func _init(initial_progress: Dictionary) -> void:
	set_progress(initial_progress)

func set_progress(updated_progress: Dictionary) -> void:
	progress = updated_progress
	selected_index = 0
	var vehicles := VehicleCatalog.all()
	for index in vehicles.size():
		if vehicles[index].id == progress.get("selected_vehicle_id", &""):
			selected_index = index
			break

func move(direction: int) -> void:
	selected_index = clampi(selected_index + direction, 0, VehicleCatalog.all().size() - 1)

func selected_vehicle_id() -> StringName:
	return VehicleCatalog.all()[selected_index].id

func can_confirm() -> bool:
	return TourProgress.is_vehicle_unlocked(progress, selected_vehicle_id())

func confirm() -> bool:
	return TourProgress.select_vehicle(progress, selected_vehicle_id())

func selected_state() -> Dictionary:
	var vehicle := VehicleCatalog.get_by_id(selected_vehicle_id())
	vehicle.unlocked = can_confirm()
	vehicle.unlock_key = UNLOCK_KEYS.get(vehicle.id, &"unlock_starter")
	return vehicle
