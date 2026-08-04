extends "res://scripts/save_store.gd"

func _promote_temp_file(_temporary_path: String, target_path: String) -> Error:
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path))
	return ERR_CANT_CREATE
