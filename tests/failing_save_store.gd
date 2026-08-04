extends "res://scripts/save_store.gd"

func _promote_temp_file(_temporary_path: String, _target_path: String) -> Error:
	return ERR_CANT_CREATE
