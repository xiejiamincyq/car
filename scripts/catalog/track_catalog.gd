class_name TrackCatalog
extends RefCounted

const NEON_COAST_LEFT_SEQUENCE := [
	"res://assets/environment_sequences/neon_coast/left_00.png",
	"res://assets/environment_sequences/neon_coast/left_01.png",
	"res://assets/environment_sequences/neon_coast/left_02.png",
	"res://assets/environment_sequences/neon_coast/left_03.png",
	"res://assets/environment_sequences/neon_coast/left_04.png",
]
const NEON_COAST_RIGHT_SEQUENCE := [
	"res://assets/environment_sequences/neon_coast/right_00.png",
	"res://assets/environment_sequences/neon_coast/right_01.png",
	"res://assets/environment_sequences/neon_coast/right_02.png",
	"res://assets/environment_sequences/neon_coast/right_03.png",
	"res://assets/environment_sequences/neon_coast/right_04.png",
]
const FREIGHT_HARBOR_LEFT_SEQUENCE := [
	"res://assets/environment_sequences/freight_harbor/left_00.png",
	"res://assets/environment_sequences/freight_harbor/left_01.png",
	"res://assets/environment_sequences/freight_harbor/left_02.png",
	"res://assets/environment_sequences/freight_harbor/left_03.png",
	"res://assets/environment_sequences/freight_harbor/left_04.png",
]
const FREIGHT_HARBOR_RIGHT_SEQUENCE := [
	"res://assets/environment_sequences/freight_harbor/right_00.png",
	"res://assets/environment_sequences/freight_harbor/right_01.png",
	"res://assets/environment_sequences/freight_harbor/right_02.png",
	"res://assets/environment_sequences/freight_harbor/right_03.png",
	"res://assets/environment_sequences/freight_harbor/right_04.png",
]
const STORM_RIDGE_LEFT_SEQUENCE := [
	"res://assets/environment_sequences/storm_ridge/left_00.png",
	"res://assets/environment_sequences/storm_ridge/left_01.png",
	"res://assets/environment_sequences/storm_ridge/left_02.png",
	"res://assets/environment_sequences/storm_ridge/left_03.png",
	"res://assets/environment_sequences/storm_ridge/left_04.png",
]
const STORM_RIDGE_RIGHT_SEQUENCE := [
	"res://assets/environment_sequences/storm_ridge/right_00.png",
	"res://assets/environment_sequences/storm_ridge/right_01.png",
	"res://assets/environment_sequences/storm_ridge/right_02.png",
	"res://assets/environment_sequences/storm_ridge/right_03.png",
	"res://assets/environment_sequences/storm_ridge/right_04.png",
]
const SUNRISE_EXPRESS_LEFT_SEQUENCE := [
	"res://assets/environment_sequences/sunrise_express/left_00.png",
	"res://assets/environment_sequences/sunrise_express/left_01.png",
	"res://assets/environment_sequences/sunrise_express/left_02.png",
	"res://assets/environment_sequences/sunrise_express/left_03.png",
	"res://assets/environment_sequences/sunrise_express/left_04.png",
]
const SUNRISE_EXPRESS_RIGHT_SEQUENCE := [
	"res://assets/environment_sequences/sunrise_express/right_00.png",
	"res://assets/environment_sequences/sunrise_express/right_01.png",
	"res://assets/environment_sequences/sunrise_express/right_02.png",
	"res://assets/environment_sequences/sunrise_express/right_03.png",
	"res://assets/environment_sequences/sunrise_express/right_04.png",
]

const TRACKS := [
	{
		"id": &"neon_coast",
		"name_key": &"track_neon_coast",
		"checkpoint_distances": [800.0, 1600.0, 2400.0],
		"finish_distance": 3200.0,
		"traffic_interval_multiplier": 1.08,
		"lane_event_interval_multiplier": 1.18,
		"traffic_pattern": &"coast_flow",
		"steering_multiplier": 1.00,
		"environment_left_sequence_paths": NEON_COAST_LEFT_SEQUENCE,
		"environment_right_sequence_paths": NEON_COAST_RIGHT_SEQUENCE,
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
		"traffic_pattern": &"harbor_heavy",
		"steering_multiplier": 0.96,
		"environment_left_sequence_paths": FREIGHT_HARBOR_LEFT_SEQUENCE,
		"environment_right_sequence_paths": FREIGHT_HARBOR_RIGHT_SEQUENCE,
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
		"traffic_pattern": &"ridge_weave",
		"steering_multiplier": 0.90,
		"environment_left_sequence_paths": STORM_RIDGE_LEFT_SEQUENCE,
		"environment_right_sequence_paths": STORM_RIDGE_RIGHT_SEQUENCE,
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
		"traffic_pattern": &"express_fast",
		"steering_multiplier": 1.04,
		"environment_left_sequence_paths": SUNRISE_EXPRESS_LEFT_SEQUENCE,
		"environment_right_sequence_paths": SUNRISE_EXPRESS_RIGHT_SEQUENCE,
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
		if String(track.get("traffic_pattern", &"")).is_empty():
			errors.append("Track %s needs a traffic pattern" % track_id)
		var steering_multiplier := float(track.get("steering_multiplier", 0.0))
		if steering_multiplier < 0.85 or steering_multiplier > 1.10:
			errors.append("Track %s steering multiplier is outside the readable range" % track_id)
		var left_paths: Array = track.get("environment_left_sequence_paths", [])
		var right_paths: Array = track.get("environment_right_sequence_paths", [])
		if left_paths.size() < 2 or left_paths.size() != right_paths.size():
			errors.append("Track %s needs paired multi-part environment sequences" % track_id)
		for side_paths in [left_paths, right_paths]:
			var seen_paths := {}
			for path_value in side_paths:
				var path := String(path_value)
				if path.is_empty() or not ResourceLoader.exists(path):
					errors.append("Track %s needs valid environment sequence textures" % track_id)
				if seen_paths.has(path):
					errors.append("Track %s may not repeat an environment texture" % track_id)
				seen_paths[path] = true
	return errors

static func _strictly_increasing(values: Array) -> bool:
	for index in range(1, values.size()):
		if float(values[index]) <= float(values[index - 1]):
			return false
	return true
