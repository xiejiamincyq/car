extends SceneTree

const SaveStore = preload("res://scripts/save_store.gd")
const FailingSaveStore = preload("res://tests/failing_save_store.gd")

var test_path := "user://test_neon_coast_save.cfg"

func _init() -> void:
	_cleanup()

	var store := SaveStore.new(test_path)
	var defaults: Dictionary = store.load_data()
	assert(defaults.version == SaveStore.CURRENT_VERSION and defaults.top_scores.is_empty(), "A missing save must return safe defaults")

	var expected := SaveStore.default_data()
	expected.settings.audio_volume = 0.4
	expected.settings.audio_muted = true
	expected.settings.difficulty = 2
	expected.career.runs = 7
	expected.career.total_distance = 4321.5
	expected.top_scores = [{"score": 900, "difficulty": 2, "distance": 740.0, "date": "2026-08-04"}]
	assert(store.save_data(expected), "A valid save must be written")
	var loaded: Dictionary = store.load_data()
	assert(loaded == expected, "A valid save must round-trip without changing typed values")

	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	corrupt.store_string("not a ConfigFile")
	corrupt.close()
	assert(store.load_data() == SaveStore.default_data(), "Corrupt files must recover to safe defaults")

	var wrong_types := ConfigFile.new()
	wrong_types.set_value("meta", "version", SaveStore.CURRENT_VERSION)
	wrong_types.set_value("settings", "audio_volume", "loud")
	wrong_types.save(test_path)
	assert(store.load_data() == SaveStore.default_data(), "Wrong field types must not escape into gameplay")

	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 0)
	legacy.set_value("progress", "best_score", 1200)
	legacy.save(test_path)
	var migrated: Dictionary = store.load_data()
	assert(migrated.version == SaveStore.CURRENT_VERSION and migrated.top_scores[0].score == 1200, "Version zero must migrate its best score")

	assert(store.save_data(expected), "The pre-failure save must exist")
	var failing_store := FailingSaveStore.new(test_path)
	var replacement := expected.duplicate(true)
	replacement.career.runs = 99
	assert(not failing_store.save_data(replacement), "A failed promotion must report failure")
	assert(store.load_data().career.runs == 7, "A failed promotion must preserve the prior readable save")

	_cleanup()
	quit()

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = test_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
