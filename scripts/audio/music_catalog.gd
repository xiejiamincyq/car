class_name MusicCatalog
extends RefCounted

const TRACKS := {
	&"neon_coast": {
		"id": &"neon_coast",
		"title": "Neon Coast Circuit",
		"path": "res://assets/music/neon_coast.ogg",
		"source_path": "res://art/source/music/generate_neon_coast.py",
		"duration_seconds": 64.0,
		"gain_db": -4.0,
	}
}

static func get_by_id(track_id: StringName) -> Dictionary:
	return TRACKS.get(track_id, {}).duplicate(true)

static func stream_for(track_id: StringName) -> AudioStream:
	var profile := get_by_id(track_id)
	if profile.is_empty():
		return null
	var path := String(profile.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		stream.set("loop", true)
	return stream

static func gain_db_for(track_id: StringName) -> float:
	return float(get_by_id(track_id).get("gain_db", 0.0))

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for key in TRACKS:
		var track_id := key as StringName
		var profile: Dictionary = TRACKS[key]
		if profile.get("id", &"") != track_id:
			errors.append("Track id does not match catalog key: %s" % track_id)
		var duration := float(profile.get("duration_seconds", 0.0))
		if duration < 60.0 or duration > 90.0:
			errors.append("Track duration must be between 60 and 90 seconds: %s" % track_id)
		for path_key in ["path", "source_path"]:
			var path := String(profile.get(path_key, ""))
			if path.is_empty() or not FileAccess.file_exists(path):
				errors.append("Missing %s for track %s: %s" % [path_key, track_id, path])
	return errors
