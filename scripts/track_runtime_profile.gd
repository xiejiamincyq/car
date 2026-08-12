class_name TrackRuntimeProfile
extends RefCounted

const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")

static func resolve(track_id: StringName) -> Dictionary:
	var profile := TrackCatalog.get_by_id(track_id)
	return profile if not profile.is_empty() else TrackCatalog.get_by_id(&"neon_coast")

static func textures_for(profile: Dictionary, side: String, fallback: Texture2D) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var sequence_paths: Array = profile.get("environment_%s_sequence_paths" % side, [])
	for path_value in sequence_paths:
		var path := String(path_value)
		var texture := load(path) as Texture2D
		if texture != null:
			textures.append(texture)
	if textures.is_empty():
		textures.append(fallback)
	return textures

static func apply(profile: Dictionary, drive, run, traffic) -> void:
	drive.steering_speed *= float(profile.get("steering_multiplier", 1.0))
	run.configure_track(profile)
	traffic.configure_track(profile)
