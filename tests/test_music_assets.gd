extends SceneTree

const MusicCatalog = preload("res://scripts/audio/music_catalog.gd")

func _init() -> void:
	var errors := MusicCatalog.validate()
	assert(errors.is_empty(), "The technical music sample must satisfy its catalog contract: %s" % "; ".join(errors))
	var profile := MusicCatalog.get_by_id(&"neon_coast")
	assert(not profile.is_empty(), "Neon Coast must have a music catalog entry")
	assert(float(profile.duration_seconds) >= 60.0 and float(profile.duration_seconds) <= 90.0, "The technical sample must be a 60-90 second loop")
	assert(FileAccess.file_exists(String(profile.path)), "The runtime music asset must exist")
	assert(FileAccess.file_exists(String(profile.source_path)), "The reproducible source generator must be retained")
	assert(FileAccess.get_file_as_bytes(String(profile.path)).size() <= 2_500_000, "The technical sample must stay within the runtime size budget")
	assert(float(profile.gain_db) <= -3.0, "Music must retain enough mix headroom for gameplay warnings and collision cues")
	var report_data = JSON.parse_string(FileAccess.get_file_as_string("res://art/source/music/neon_coast_build.json"))
	assert(report_data is Dictionary, "The reproducible music build report must be valid JSON")
	assert(absf(float(report_data.decoded_duration_seconds) - float(profile.duration_seconds)) <= 0.01, "Encoded and catalog durations must agree")
	assert(float(report_data.loop_seam_max_abs) <= 0.01, "The decoded loop boundary must not contain a click-sized discontinuity")
	assert(float(report_data.integrated_lufs) + float(profile.gain_db) <= -20.0, "Runtime music loudness must leave headroom for critical effects")
	assert(float(report_data.true_peak_dbfs) <= -1.0, "The encoded technical sample must retain true-peak headroom")
	var stream := MusicCatalog.stream_for(&"neon_coast")
	assert(stream != null and bool(stream.get("loop")), "The runtime stream must load with seamless looping enabled")
	assert(MusicCatalog.stream_for(&"missing") == null, "Unknown or unfinished tracks must use the silent fallback")
	quit()
