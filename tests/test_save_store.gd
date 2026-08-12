extends SceneTree

const SaveStore = preload("res://scripts/save_store.gd")
const FailingSaveStore = preload("res://tests/failing_save_store.gd")

var test_path := "user://test_neon_coast_save.cfg"

func _init() -> void:
	_cleanup()

	var store := SaveStore.new(test_path)
	var defaults: Dictionary = store.load_data()
	assert(defaults.version == SaveStore.CURRENT_VERSION and defaults.top_scores.is_empty(), "A missing save must return safe defaults")
	assert(defaults.settings.language == "system", "A missing save must follow the system language by default")
	assert(defaults.settings.music_volume == 0.65 and defaults.settings.effects_volume == 0.65, "A fresh v5 save must expose independent audio channel volumes")
	assert(defaults.tour.selected_track_id == &"neon_coast" and defaults.tour.selected_vehicle_id == &"pulse_gt", "A fresh v5 save must select safe starter content")

	var expected := SaveStore.default_data()
	expected.settings.audio_volume = 0.4
	expected.settings.music_volume = 0.3
	expected.settings.effects_volume = 0.7
	expected.settings.audio_muted = true
	expected.settings.difficulty = 2
	expected.settings.fullscreen = true
	expected.settings.language = "en"
	expected.settings.high_contrast = true
	expected.settings.reduced_flashing = true
	expected.settings.screen_shake = false
	expected.career.runs = 7
	expected.career.total_distance = 4321.5
	expected.top_scores = [{"score": 900, "difficulty": 2, "distance": 740.0, "date": "2026-08-04"}]
	expected.tour.selected_vehicle_id = &"driftwing"
	expected.tour.track_results.neon_coast = {"cleared": true, "best_score": 6200, "best_time": 198.5, "medal": 2}
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

	var version_one := ConfigFile.new()
	version_one.set_value("meta", "version", 1)
	version_one.set_value("scores", "items", expected.top_scores)
	version_one.set_value("settings", "audio_volume", 0.4)
	version_one.set_value("settings", "audio_muted", true)
	version_one.set_value("settings", "difficulty", 2)
	for key in expected.career:
		version_one.set_value("career", key, expected.career[key])
	version_one.save(test_path)
	var migrated_v1 := store.load_data()
	assert(migrated_v1.version == SaveStore.CURRENT_VERSION and migrated_v1.settings.audio_volume == 0.4 and migrated_v1.settings.difficulty == 2, "Version one settings must migrate without data loss")
	assert(migrated_v1.settings.music_volume == 0.4 and migrated_v1.settings.effects_volume == 0.4, "Legacy audio volume must seed both v5 channels")
	assert(migrated_v1.tour == SaveStore.default_data().tour, "Legacy saves must receive safe fresh tour progress")
	assert(not migrated_v1.settings.fullscreen, "Version one saves must receive the safe windowed default")
	assert(migrated_v1.settings.language == "system", "Version one saves must receive the system language default")

	var version_two := ConfigFile.new()
	version_two.set_value("meta", "version", 2)
	version_two.set_value("scores", "items", expected.top_scores)
	version_two.set_value("settings", "audio_volume", 0.4)
	version_two.set_value("settings", "audio_muted", true)
	version_two.set_value("settings", "difficulty", 2)
	version_two.set_value("settings", "fullscreen", true)
	for key in expected.career:
		version_two.set_value("career", key, expected.career[key])
	version_two.save(test_path)
	var migrated_v2 := store.load_data()
	assert(migrated_v2.version == SaveStore.CURRENT_VERSION and migrated_v2.settings.fullscreen, "Version two display settings must migrate without data loss")
	assert(migrated_v2.settings.language == "system", "Version two saves must receive the system language default")

	var version_three := ConfigFile.new()
	version_three.set_value("meta", "version", 3)
	version_three.set_value("scores", "items", expected.top_scores)
	version_three.set_value("settings", "audio_volume", 0.4)
	version_three.set_value("settings", "audio_muted", true)
	version_three.set_value("settings", "difficulty", 2)
	version_three.set_value("settings", "fullscreen", true)
	version_three.set_value("settings", "language", "en")
	for key in expected.career:
		version_three.set_value("career", key, expected.career[key])
	version_three.save(test_path)
	var migrated_v3 := store.load_data()
	assert(migrated_v3.version == SaveStore.CURRENT_VERSION and migrated_v3.settings.language == "en", "Version three language settings must migrate without data loss")
	assert(not migrated_v3.settings.high_contrast and not migrated_v3.settings.reduced_flashing and migrated_v3.settings.screen_shake, "Version three saves must receive safe accessibility defaults")

	var version_four := ConfigFile.new()
	version_four.set_value("meta", "version", 4)
	version_four.set_value("scores", "items", expected.top_scores)
	for key in ["audio_volume", "audio_muted", "difficulty", "fullscreen", "language", "high_contrast", "reduced_flashing", "screen_shake"]:
		version_four.set_value("settings", key, expected.settings[key])
	for key in expected.career:
		version_four.set_value("career", key, expected.career[key])
	version_four.save(test_path)
	var migrated_v4 := store.load_data()
	assert(migrated_v4.settings.music_volume == 0.4 and migrated_v4.settings.effects_volume == 0.4, "Version four audio volume must seed both v5 channels")
	assert(migrated_v4.tour == SaveStore.default_data().tour, "Version four must gain safe tour defaults without losing old data")

	var damaged_v5 := ConfigFile.new()
	damaged_v5.set_value("meta", "version", SaveStore.CURRENT_VERSION)
	for key in expected.settings:
		damaged_v5.set_value("settings", key, expected.settings[key])
	for key in expected.career:
		damaged_v5.set_value("career", key, expected.career[key])
	damaged_v5.set_value("scores", "items", expected.top_scores)
	damaged_v5.set_value("tour", "selected_track_id", &"missing")
	damaged_v5.set_value("tour", "selected_vehicle_id", &"aurora_x")
	damaged_v5.set_value("tour", "track_results", {&"neon_coast": {"cleared": "yes"}})
	damaged_v5.save(test_path)
	assert(store.load_data() == SaveStore.default_data(), "Invalid v5 tour fields must fail closed to safe defaults")

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
