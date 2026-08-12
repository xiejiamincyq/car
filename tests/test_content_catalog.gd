extends SceneTree

const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")

func _init() -> void:
	_assert_track_contract()
	_assert_vehicle_contract()
	quit()

func _assert_track_contract() -> void:
	var tracks := TrackCatalog.all()
	assert(tracks.size() == 4, "The coastal tour must expose exactly four tracks")
	assert(_unique_ids(tracks).size() == tracks.size(), "Every track ID must be unique")
	assert(TrackCatalog.validate().is_empty(), "The frozen track catalog must satisfy its own contract")
	for track in tracks:
		assert(track.id is StringName and not String(track.id).is_empty(), "Tracks need stable StringName IDs")
		assert(track.checkpoint_distances.size() == 3, "Every track must retain four race stages")
		assert(float(track.finish_distance) > float(track.checkpoint_distances[-1]), "Finish distance must follow every checkpoint")
		assert(int(track.silver_score) > 0 and int(track.gold_score) > int(track.silver_score), "Track medal thresholds must be ordered")
		assert(track.music_id is StringName and not String(track.music_id).is_empty(), "Every track must select a music ID")
	var first_id: StringName = tracks[0].id
	tracks[0].finish_distance = -1.0
	assert(float(TrackCatalog.get_by_id(first_id).finish_distance) > 0.0, "Callers must not mutate the canonical track catalog")
	assert(TrackCatalog.get_by_id(&"missing").is_empty(), "Unknown track IDs must fail closed")

func _assert_vehicle_contract() -> void:
	var vehicles := VehicleCatalog.all()
	assert(vehicles.size() == 6, "The garage must expose exactly six player vehicles")
	assert(_unique_ids(vehicles).size() == vehicles.size(), "Every vehicle ID must be unique")
	assert(VehicleCatalog.validate().is_empty(), "The frozen vehicle catalog must satisfy its own contract")
	for vehicle in vehicles:
		assert(vehicle.id is StringName and not String(vehicle.id).is_empty(), "Vehicles need stable StringName IDs")
		assert(String(vehicle.get("texture_path", "")).begins_with("res://assets/vehicles/player_"), "Every player vehicle needs its own runtime sprite path")
		assert(ResourceLoader.exists(String(vehicle.texture_path)), "Vehicle %s sprite must exist" % vehicle.id)
		assert(float(vehicle.max_speed) > 0.0 and float(vehicle.acceleration) > 0.0, "Vehicle propulsion values must be positive")
		assert(float(vehicle.braking) > 0.0 and float(vehicle.steering_speed) > 0.0, "Vehicle control values must be positive")
		assert(float(vehicle.collision_speed_penalty) > 0.0, "Vehicle collision recovery must remain meaningful")
		var budget := VehicleCatalog.performance_budget(vehicle)
		assert(budget >= 4.75 and budget <= 5.15, "Vehicle %s must stay inside the shared performance budget: %.3f" % [vehicle.id, budget])
	var first_id: StringName = vehicles[0].id
	vehicles[0].max_speed = -1.0
	assert(float(VehicleCatalog.get_by_id(first_id).max_speed) > 0.0, "Callers must not mutate the canonical vehicle catalog")
	assert(VehicleCatalog.get_by_id(&"missing").is_empty(), "Unknown vehicle IDs must fail closed")

func _unique_ids(entries: Array) -> Dictionary:
	var ids := {}
	for entry in entries:
		ids[entry.id] = true
	return ids
