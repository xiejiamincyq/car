class_name PlaytestLaunchConfig
extends RefCounted

const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")

const DIFFICULTY_NAMES := {
	"easy": 0,
	"standard": 1,
	"hard": 2,
}

static func parse(arguments: PackedStringArray) -> Dictionary:
	if arguments.size() != 4:
		return _invalid("Expected: <track_id> <vehicle_id> <easy|standard|hard|0..2> <seed>")

	var track_id := StringName(arguments[0])
	if TrackCatalog.get_by_id(track_id).is_empty():
		return _invalid("Unknown track: %s" % arguments[0])

	var vehicle_id := StringName(arguments[1])
	if VehicleCatalog.get_by_id(vehicle_id).is_empty():
		return _invalid("Unknown vehicle: %s" % arguments[1])

	var difficulty_text := arguments[2].to_lower()
	var difficulty_index := -1
	if DIFFICULTY_NAMES.has(difficulty_text):
		difficulty_index = int(DIFFICULTY_NAMES[difficulty_text])
	elif difficulty_text.is_valid_int():
		difficulty_index = difficulty_text.to_int()
	if difficulty_index < 0 or difficulty_index > 2:
		return _invalid("Unknown difficulty: %s" % arguments[2])

	var seed_text := arguments[3]
	if not seed_text.is_valid_int() or seed_text.to_int() < 0:
		return _invalid("Seed must be a non-negative integer")

	return {
		"valid": true,
		"error": "",
		"track_id": track_id,
		"vehicle_id": vehicle_id,
		"difficulty_index": difficulty_index,
		"run_seed": seed_text.to_int(),
	}

static func _invalid(message: String) -> Dictionary:
	return {
		"valid": false,
		"error": message,
	}
