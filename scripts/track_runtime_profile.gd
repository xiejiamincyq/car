class_name TrackRuntimeProfile
extends RefCounted

const TrackCatalog = preload("res://scripts/catalog/track_catalog.gd")

static func resolve(track_id: StringName) -> Dictionary:
	var profile := TrackCatalog.get_by_id(track_id)
	return profile if not profile.is_empty() else TrackCatalog.get_by_id(&"neon_coast")

static func texture_for(profile: Dictionary, side: String, fallback: Texture2D) -> Texture2D:
	var path := String(profile.get("environment_%s_path" % side, ""))
	var texture := load(path) as Texture2D
	return texture if texture != null else fallback

static func apply(profile: Dictionary, drive, run, traffic) -> void:
	drive.steering_speed *= float(profile.get("steering_multiplier", 1.0))
	run.configure_track(profile)
	traffic.configure_track(profile)
