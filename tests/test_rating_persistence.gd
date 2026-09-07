extends SceneTree

const SaveStore = preload("res://scripts/save_store.gd")
const Progression = preload("res://scripts/progression.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const TEST_PATH := "user://test_rating_v6.cfg"

func _init() -> void:
	var store := SaveStore.new(TEST_PATH)
	var data := SaveStore.default_data()
	assert(data.version == 6 and data.ratings.is_empty(), "v6 introduces empty per-track ratings")
	var run := {"score": 7000, "difficulty": 1, "distance": 3200.0, "survival": 60.0, "overtakes": 12, "coins": 60, "collisions": 0, "near_misses": 2, "stage": 4, "track_id": &"neon_coast", "cleared": true, "medal": 2}
	var outcome := Progression.record_run(data, run, "2026-09-08")
	assert(outcome.rating.total == 100 and outcome.new_rating_record)
	assert(data.ratings.is_empty(), "Recording a run must not mutate its input")
	data = outcome.data
	assert(store.save_data(data) and store.load_data() == data)
	var best: Dictionary = data.ratings.neon_coast.duplicate(true)
	run.collisions = 5
	var worse := Progression.record_run(data, run, "2026-09-09")
	assert(worse.rating.total == 80 and not worse.new_rating_record)
	assert(worse.data.ratings.neon_coast == best)
	run.collisions = 0
	var tied := Progression.record_run(data, run, "2026-09-10")
	assert(not tied.new_rating_record and tied.data.ratings.neon_coast == best)
	run.cleared = false
	var failed := Progression.record_run(data, run, "2026-09-11")
	assert(failed.rating.is_empty() and failed.data.ratings.neon_coast == best)
	for track in Tracks.all():
		run.track_id = track.id
		run.cleared = true
		data = Progression.record_run(data, run, "2026-09-12").data
	assert(data.ratings.size() == 4, "Track records must remain independent")
	assert(store.save_data(data))
	# A real v5 ConfigFile has no rating section; migration is read-only.
	var legacy := ConfigFile.new()
	assert(legacy.load(TEST_PATH) == OK)
	legacy.set_value("meta", "version", 5)
	legacy.erase_section("ratings")
	assert(legacy.save(TEST_PATH) == OK)
	var before := FileAccess.get_file_as_bytes(TEST_PATH)
	var migrated := store.load_data()
	assert(migrated.version == 6 and migrated.ratings.is_empty())
	for key in ["settings", "career", "tour", "top_scores"]:
		assert(migrated[key] == data[key], "v5 migration must preserve %s" % key)
	assert(FileAccess.get_file_as_bytes(TEST_PATH) == before, "Loading must not rewrite the legacy file")
	var invalid := data.duplicate(true)
	invalid.ratings.neon_coast.grade = "D"
	assert(not store.save_data(invalid), "A stored grade must match its total")
	invalid = data.duplicate(true)
	invalid.ratings.neon_coast.total = 101
	assert(not store.save_data(invalid))
	assert(FileAccess.get_file_as_bytes(TEST_PATH) == before, "Rejected writes must preserve old data")
	for suffix in ["", ".tmp", ".bak"]:
		var path := ProjectSettings.globalize_path(TEST_PATH + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit()
