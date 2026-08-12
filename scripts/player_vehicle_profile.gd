class_name PlayerVehicleProfile
extends RefCounted

const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const GameConfig = preload("res://scripts/game_config.gd")
const DEFAULT_VEHICLE_ID := &"pulse_gt"

static func resolve(vehicle_id: StringName) -> Dictionary:
	var profile := VehicleCatalog.get_by_id(vehicle_id)
	return VehicleCatalog.get_by_id(DEFAULT_VEHICLE_ID) if profile.is_empty() else profile

static func apply_to_drive(profile: Dictionary, drive) -> void:
	drive.start_speed = minf(GameConfig.START_SPEED, float(profile.max_speed))
	drive.max_speed = float(profile.max_speed)
	drive.acceleration = float(profile.acceleration)
	drive.braking = float(profile.braking)
	drive.steering_speed = float(profile.steering_speed)

static func texture_for(profile: Dictionary) -> Texture2D:
	var texture := load(String(profile.texture_path)) as Texture2D
	if texture != null:
		return texture
	return load(String(resolve(DEFAULT_VEHICLE_ID).texture_path)) as Texture2D
