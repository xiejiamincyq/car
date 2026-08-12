class_name TrackCatalog
extends RefCounted

const TRACKS := [
	{
		"id": &"neon_coast",
		"name_key": &"track_neon_coast",
		"checkpoint_distances": [800.0, 1600.0, 2400.0],
		"finish_distance": 3200.0,
		"traffic_interval_multiplier": 1.08,
		"lane_event_interval_multiplier": 1.18,
		"silver_score": 5200,
		"gold_score": 7600,
		"music_id": &"neon_coast",
	},
	{
		"id": &"freight_harbor",
		"name_key": &"track_freight_harbor",
		"checkpoint_distances": [850.0, 1700.0, 2550.0],
		"finish_distance": 3400.0,
		"traffic_interval_multiplier": 1.02,
		"lane_event_interval_multiplier": 1.12,
		"silver_score": 5700,
		"gold_score": 8300,
		"music_id": &"freight_harbor",
	},
	{
		"id": &"storm_ridge",
		"name_key": &"track_storm_ridge",
		"checkpoint_distances": [825.0, 1650.0, 2475.0],
		"finish_distance": 3300.0,
		"traffic_interval_multiplier": 0.98,
		"lane_event_interval_multiplier": 1.05,
		"silver_score": 6100,
		"gold_score": 8900,
		"music_id": &"storm_ridge",
	},
	{
		"id": &"sunrise_express",
		"name_key": &"track_sunrise_express",
		"checkpoint_distances": [900.0, 1800.0, 2700.0],
		"finish_distance": 3600.0,
		"traffic_interval_multiplier": 0.92,
		"lane_event_interval_multiplier": 0.96,
		"silver_score": 6700,
		"gold_score": 9800,
		"music_id": &"sunrise_express",
	},
]

static func all() -> Array:
	return TRACKS.duplicate(true)

static func get_by_id(track_id: StringName) -> Dictionary:
	for track in TRACKS:
		if track.id == track_id:
			return track.duplicate(true)
	return {}

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for track in TRACKS:
		var track_id: StringName = track.get("id", &"")
		if String(track_id).is_empty() or ids.has(track_id):
			errors.append("Track IDs must be present and unique")
		ids[track_id] = true
		var checkpoints: Array = track.get("checkpoint_distances", [])
		if checkpoints.size() != 3 or not _strictly_increasing(checkpoints):
			errors.append("Track %s must have three ordered checkpoints" % track_id)
		elif float(track.get("finish_distance", 0.0)) <= float(checkpoints[-1]):
			errors.append("Track %s finish must follow its checkpoints" % track_id)
		if int(track.get("silver_score", 0)) <= 0 or int(track.get("gold_score", 0)) <= int(track.get("silver_score", 0)):
			errors.append("Track %s medal thresholds must be ordered" % track_id)
		if String(track.get("music_id", &"")).is_empty():
			errors.append("Track %s needs a music ID" % track_id)
	return errors

static func _strictly_increasing(values: Array) -> bool:
	for index in range(1, values.size()):
		if float(values[index]) <= float(values[index - 1]):
			return false
	return true
