class_name SaveStore
extends RefCounted

const CURRENT_VERSION := 1

var save_path: String

func _init(path: String = "user://save.cfg") -> void:
	save_path = path

static func default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"top_scores": [],
		"settings": {
			"audio_volume": 0.65,
			"audio_muted": false,
			"difficulty": 1,
		},
		"career": {
			"runs": 0,
			"total_distance": 0.0,
			"overtakes": 0,
			"near_misses": 0,
			"longest_survival": 0.0,
			"highest_stage": 0,
		},
	}

func load_data() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return default_data()
	var version = _value_or_null(config, "meta", "version")
	if typeof(version) != TYPE_INT:
		return default_data()
	if version == 0:
		return _migrate_version_zero(config)
	if version != CURRENT_VERSION:
		return default_data()
	var candidate := {
		"version": version,
		"top_scores": config.get_value("scores", "items", []),
		"settings": {
			"audio_volume": _value_or_null(config, "settings", "audio_volume"),
			"audio_muted": _value_or_null(config, "settings", "audio_muted"),
			"difficulty": _value_or_null(config, "settings", "difficulty"),
		},
		"career": {
			"runs": _value_or_null(config, "career", "runs"),
			"total_distance": _value_or_null(config, "career", "total_distance"),
			"overtakes": _value_or_null(config, "career", "overtakes"),
			"near_misses": _value_or_null(config, "career", "near_misses"),
			"longest_survival": _value_or_null(config, "career", "longest_survival"),
			"highest_stage": _value_or_null(config, "career", "highest_stage"),
		},
	}
	var validated := _validated_data(candidate)
	return default_data() if validated.is_empty() else validated

func save_data(data: Dictionary) -> bool:
	var validated := _validated_data(data)
	if validated.is_empty():
		return false
	var config := ConfigFile.new()
	config.set_value("meta", "version", CURRENT_VERSION)
	config.set_value("scores", "items", validated.top_scores)
	for key in validated.settings:
		config.set_value("settings", key, validated.settings[key])
	for key in validated.career:
		config.set_value("career", key, validated.career[key])

	var temporary_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	if config.save(temporary_path) != OK:
		return false
	var target_absolute := ProjectSettings.globalize_path(save_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_absolute)
		if DirAccess.copy_absolute(target_absolute, backup_absolute) != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
			return false

	var promote_error := _promote_temp_file(temporary_path, save_path)
	if promote_error != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(save_path):
			DirAccess.copy_absolute(backup_absolute, target_absolute)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		DirAccess.remove_absolute(backup_absolute)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	return true

func _promote_temp_file(temporary_path: String, target_path: String) -> Error:
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var target_absolute := ProjectSettings.globalize_path(target_path)
	if FileAccess.file_exists(target_path):
		var remove_error := DirAccess.remove_absolute(target_absolute)
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(temporary_absolute, target_absolute)

static func _validated_data(data: Dictionary) -> Dictionary:
	if typeof(data.get("version")) != TYPE_INT or data.version != CURRENT_VERSION:
		return {}
	if typeof(data.get("settings")) != TYPE_DICTIONARY or typeof(data.get("career")) != TYPE_DICTIONARY or typeof(data.get("top_scores")) != TYPE_ARRAY:
		return {}
	var settings: Dictionary = data.settings
	var career: Dictionary = data.career
	if not _is_number(settings.get("audio_volume")) or typeof(settings.get("audio_muted")) != TYPE_BOOL or typeof(settings.get("difficulty")) != TYPE_INT:
		return {}
	if settings.audio_volume < 0.0 or settings.audio_volume > 1.0 or settings.difficulty < 0 or settings.difficulty > 2:
		return {}
	if typeof(career.get("runs")) != TYPE_INT or not _is_number(career.get("total_distance")) or typeof(career.get("overtakes")) != TYPE_INT or typeof(career.get("near_misses")) != TYPE_INT or not _is_number(career.get("longest_survival")) or typeof(career.get("highest_stage")) != TYPE_INT:
		return {}
	if career.runs < 0 or career.total_distance < 0.0 or career.overtakes < 0 or career.near_misses < 0 or career.longest_survival < 0.0 or career.highest_stage < 0:
		return {}
	var scores: Array = data.top_scores
	if scores.size() > 5:
		return {}
	for item in scores:
		if typeof(item) != TYPE_DICTIONARY:
			return {}
		if typeof(item.get("score")) != TYPE_INT or typeof(item.get("difficulty")) != TYPE_INT or not _is_number(item.get("distance")) or typeof(item.get("date")) != TYPE_STRING:
			return {}
		if item.score < 0 or item.difficulty < 0 or item.difficulty > 2 or item.distance < 0.0:
			return {}
	return data.duplicate(true)

static func _migrate_version_zero(config: ConfigFile) -> Dictionary:
	var best_score = config.get_value("progress", "best_score", 0)
	if typeof(best_score) != TYPE_INT or best_score < 0:
		return default_data()
	var migrated := default_data()
	if best_score > 0:
		migrated.top_scores.append({"score": best_score, "difficulty": 1, "distance": 0.0, "date": "legacy"})
	return migrated

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT

static func _value_or_null(config: ConfigFile, section: String, key: String) -> Variant:
	return config.get_value(section, key) if config.has_section_key(section, key) else null
