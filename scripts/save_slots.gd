extends RefCounted
## Four isolated SaveStores; the original single save is a read-only migration source.
const Store = preload("res://scripts/save_store.gd")
const SLOT_COUNT := 4
var root_path: String
var legacy_path: String
var active_slot := 0
var ready_to_write := false
var last_error: Error = OK
var last_archive_path := ""
func _init(directory := "user://save_slots", original := "user://save.cfg") -> void:
	root_path=directory.trim_suffix("/")
	legacy_path=original
func slot_count() -> int:return SLOT_COUNT
func _valid(index: int) -> bool:return index>=1 and index<=SLOT_COUNT
func _slot_dir(index: int) -> String:return root_path+"/slot_%d" % index
func _registry_path() -> String:return root_path+"/registry.cfg"
func _make_dir(path: String) -> bool:
	last_error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	return last_error==OK
func initialize() -> bool:
	ready_to_write=false
	if root_path!=root_path.simplify_path() or root_path in ["user:","user://","res:","res://","res://tmp"] or not (root_path.begins_with("user://") or root_path.begins_with("res://tmp/")):
		last_error=ERR_INVALID_PARAMETER;return false
	if not _make_dir(root_path):return false
	var registry := _read_registry(_registry_path())
	if registry.status!=&"valid":
		var backup := _read_registry(_registry_path()+".bak")
		if backup.status==&"valid":registry=backup
		elif registry.status!=&"missing" or backup.status!=&"missing":last_error=ERR_INVALID_DATA;return false
	if registry.status==&"valid":
		active_slot=registry.active
		# A recovered old pointer must not recreate a directory moved to recovery.
		# Explicitly selected empty slots already have directories from activate_slot.
		if active_slot>0 and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_slot_dir(active_slot))):
			if not _write_registry(0):return false
			active_slot=0
		ready_to_write=true
		return ready_to_write
	var existing := 0
	for index in range(1,5):
		if slot_info(index).status in [&"primary",&"backup"]:existing=index;break
	if existing==0:
		var original_store := Store.new(legacy_path)
		var data := original_store.load_data()
		if original_store.last_load_status in [&"invalid",&"io_error"]:last_error=ERR_INVALID_DATA;return false
		if not _make_dir(_slot_dir(1)):return false
		if original_store.last_load_status in [&"primary",&"backup"]:
			if slot_info(1).status!=&"missing" or not Store.new(_slot_dir(1)+"/save.cfg").save_data(data):last_error=ERR_CANT_CREATE;return false
		existing=1
	if not _write_registry(existing):return false
	active_slot=existing
	ready_to_write=true
	return true
func slot_info(index: int) -> Dictionary:
	if not _valid(index):return {"index":index,"status":&"invalid_index","data":{},"active":false}
	var store := Store.new(_slot_dir(index)+"/save.cfg")
	var data := store.load_data()
	return {"index":index,"status":store.last_load_status,"data":data,"active":active_slot==index}
func active_store() -> Store:
	return Store.new(_slot_dir(active_slot)+"/save.cfg") if _valid(active_slot) else null
func _can_mutate() -> bool:
	if not ready_to_write:last_error=ERR_UNAVAILABLE;return false
	var registry := _read_registry(_registry_path())
	if registry.status!=&"valid":registry=_read_registry(_registry_path()+".bak")
	if registry.status==&"valid" and registry.active==active_slot:return true
	ready_to_write=false
	last_error=ERR_INVALID_DATA
	return false
func activate_slot(index: int) -> bool:
	if not _valid(index):last_error=ERR_INVALID_PARAMETER;return false
	if not _can_mutate():return false
	if slot_info(index).status not in [&"primary",&"backup",&"missing"]:last_error=ERR_INVALID_DATA;return false
	if not _make_dir(_slot_dir(index)) or not _write_registry(index):return false
	active_slot=index
	return true
func copy_slot(source: int, target: int, overwrite_confirmed := false) -> bool:
	last_archive_path=""
	if not _valid(source) or not _valid(target) or source==target:last_error=ERR_INVALID_PARAMETER;return false
	if not _can_mutate():return false
	var original := slot_info(source)
	var destination := slot_info(target)
	if original.status not in [&"primary",&"backup"] or destination.status==&"io_error":last_error=ERR_INVALID_DATA;return false
	if destination.status!=&"missing" and not overwrite_confirmed:last_error=ERR_ALREADY_IN_USE;return false
	var staging := root_path+"/staging/copy-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	if not _make_dir(staging):return false
	var clone := Store.new(staging+"/save.cfg")
	if not clone.save_data(original.data) or clone.load_data()!=original.data:last_error=ERR_CANT_CREATE;return false
	var archived := ""
	var destination_dir := _slot_dir(target)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination_dir)):
		archived=_archive_directory(target)
		if archived.is_empty():return false
	last_error=_rename_directory(staging,destination_dir)
	if last_error!=OK:
		if not archived.is_empty() and _rename_directory(archived,destination_dir)!=OK:ready_to_write=false
		return false
	last_archive_path=archived
	return true
func delete_slot(index: int, confirmed := false) -> bool:
	last_archive_path=""
	if not _valid(index) or not confirmed:last_error=ERR_INVALID_PARAMETER;return false
	if not _can_mutate():return false
	if slot_info(index).status==&"missing":last_error=ERR_DOES_NOT_EXIST;return false
	var archived := _archive_directory(index)
	if archived.is_empty():return false
	if active_slot==index and not _write_registry(0):
		if _rename_directory(archived,_slot_dir(index))!=OK:ready_to_write=false
		return false
	if active_slot==index:active_slot=0
	last_archive_path=archived
	return true
func _archive_directory(index: int) -> String:
	var recovery := root_path+"/recovery"
	if not _make_dir(recovery):return ""
	var path := recovery+"/slot_%d-%d-%d" % [index,OS.get_process_id(),Time.get_ticks_usec()]
	last_error=_rename_directory(_slot_dir(index),path)
	return path if last_error==OK else ""
func _rename_directory(source: String, target: String) -> Error:
	# Both are fixed descendants of the validated profile root; no recursive delete.
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source),ProjectSettings.globalize_path(target))
func _read_registry(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:return {"status":&"missing" if FileAccess.get_open_error()==ERR_FILE_NOT_FOUND else &"io_error"}
	var content := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	var config := ConfigFile.new()
	if read_error not in [OK,ERR_FILE_EOF] or config.parse(content)!=OK:return {"status":&"invalid"}
	for key in ["active","version","legacy_import_done"]:
		if not config.has_section_key("slots",key):return {"status":&"invalid"}
	var index = config.get_value("slots","active")
	var version = config.get_value("slots","version")
	var imported = config.get_value("slots","legacy_import_done")
	if not version is int or version!=1 or not index is int or index<0 or index>4 or not imported is bool or not imported:return {"status":&"invalid"}
	return {"status":&"valid","active":index}
func _write_registry(index: int) -> bool:
	var path := _registry_path()
	var primary := _read_registry(path)
	var backup := _read_registry(path+".bak")
	if primary.status==&"io_error" or backup.status==&"io_error" or (primary.status!=&"valid" and backup.status!=&"valid" and (primary.status!=&"missing" or backup.status!=&"missing")):
		last_error=ERR_INVALID_DATA;return false
	var config := ConfigFile.new()
	config.set_value("slots","version",1)
	config.set_value("slots","active",index)
	config.set_value("slots","legacy_import_done",true)
	last_error=config.save(path+".tmp")
	if last_error!=OK:return false
	if primary.status==&"valid":
		last_error=DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".bak"))
		if last_error!=OK:return false
	last_error=Store.new()._promote_temp_file(path+".tmp",path)
	if last_error!=OK and _read_registry(path+".bak").status==&"valid" and not FileAccess.file_exists(path):DirAccess.copy_absolute(ProjectSettings.globalize_path(path+".bak"),ProjectSettings.globalize_path(path))
	return last_error==OK
