extends SceneTree
const Slots = preload("res://scripts/save_slots.gd")
const Store = preload("res://scripts/save_store.gd")
class FailPublish extends Slots:
	var fail_publish := false
	func _rename_directory(source: String,target: String) -> Error:
		if fail_publish and source.contains("/staging/"):return ERR_CANT_CREATE
		return super(source,target)
class FailRegistry extends Slots:
	var fail_registry := false
	func _write_registry(index: int) -> bool:
		if fail_registry:last_error=ERR_CANT_CREATE;return false
		return super(index)
var failures: Array[String] = []
var checks := 0
func _init() -> void:call_deferred("_run")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func _fixture(name: String):
	var path := "res://tmp/save-slots-failure-%d-%d-%s" % [OS.get_process_id(),Time.get_ticks_usec(),name]
	var manager := FailPublish.new(path,path+"/absent-legacy.cfg")
	_check(manager.initialize(),"Initialize isolated failure fixture")
	return manager
func _run() -> void:
	var manager = _fixture("copy")
	var data := Store.default_data()
	data.career.runs=11
	_check(manager.active_store().save_data(data),"Create source fixture")
	_check(manager.activate_slot(2),"Activate destination")
	data.career.runs=22
	_check(manager.active_store().save_data(data),"Create target fixture")
	manager.fail_publish=true
	_check(not manager.copy_slot(1,2,true),"Interrupted publication reports failure")
	_check(manager.slot_info(1).data.career.runs==11 and manager.slot_info(2).data.career.runs==22,"Publication failure restores destination and source unchanged")
	_check(manager.active_slot==2,"Publication failure cannot switch current identity")
	var corruption := ConfigFile.new()
	corruption.set_value("unknown","bad",true)
	_check(corruption.save(manager.root_path+"/registry.cfg")==OK and corruption.save(manager.root_path+"/registry.cfg.bak")==OK,"Inject a damaged registry only in the fixture")
	var before := FileAccess.get_sha256(manager.root_path+"/slot_1/save.cfg")
	_check(not manager.delete_slot(1,true) and not manager.copy_slot(2,1,true),"A damaged registry blocks destructive changes even on an already-loaded manager")
	_check(FileAccess.get_sha256(manager.root_path+"/slot_1/save.cfg")==before,"Failed registry guard leaves both valid payloads untouched")
	var closed = Slots.new(manager.root_path,manager.legacy_path)
	_check(not closed.initialize(),"Damaged registry cannot initialize a writable session")
	var invalid = Slots.new("res://tmp/../","user://save.cfg")
	_check(not invalid.initialize(),"Unsafe roots and traversal are rejected")
	var rollback_path := "res://tmp/save-slots-rollback-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var rollback := FailRegistry.new(rollback_path,rollback_path+"/absent.cfg")
	_check(rollback.initialize() and rollback.active_store().save_data(data),"Create delete rollback fixture")
	rollback.fail_registry=true
	_check(not rollback.delete_slot(1,true),"Failed current-pointer update is not a successful deletion")
	_check(rollback.active_slot==1 and rollback.slot_info(1).data.career.runs==22,"Interrupted delete restores original active payload")
	var backup_manager = _fixture("backup")
	_check(backup_manager.active_store().save_data(data),"First profile write")
	data.career.runs=23
	_check(backup_manager.active_store().save_data(data),"Second write creates a validated profile backup")
	var bad := ConfigFile.new()
	bad.set_value("bad","payload",true)
	_check(bad.save(backup_manager.root_path+"/slot_1/save.cfg")==OK,"Damage isolated primary")
	_check(backup_manager.slot_info(1).status==&"backup" and backup_manager.slot_info(1).data.career.runs==22,"Profile recovery reads validated backup, not defaults")
	_check(backup_manager.copy_slot(1,4),"Recovered backup can be copied into an empty profile")
	_check(backup_manager.slot_info(4).data.career.runs==22,"Recovered clone uses backup progress")
	_check(bad.save(backup_manager.root_path+"/slot_1/save.cfg.bak")==OK,"Damage isolated backup")
	_check(not backup_manager.activate_slot(1) and not backup_manager.copy_slot(1,3),"Both damaged payloads cannot be loaded or copied as defaults")
	_check(backup_manager.activate_slot(4),"Healthy profile remains available")
	_check(bad.save(backup_manager.root_path+"/registry.cfg")==OK,"Damage registry primary only")
	var recovered := Slots.new(backup_manager.root_path,backup_manager.legacy_path)
	_check(recovered.initialize() and recovered.active_slot==1,"Registry backup recovers last validated identity")
	_check(recovered.activate_slot(4),"Recovering registry can be repaired by explicit valid selection")
	var stale := Slots.new(backup_manager.root_path,backup_manager.legacy_path)
	_check(stale.initialize() and recovered.activate_slot(3),"Create two sessions with different current identities")
	_check(not stale.copy_slot(4,2,true) and not stale.ready_to_write,"Stale session cannot mutate another session's profile")
	var deleted = _fixture("deleted-pointer")
	_check(deleted.active_store().save_data(data) and deleted.delete_slot(1,true),"Delete active profile with registry backup")
	_check(bad.save(deleted.root_path+"/registry.cfg")==OK,"Inject damaged current registry after deletion")
	var after_delete := Slots.new(deleted.root_path,deleted.legacy_path)
	_check(after_delete.initialize() and after_delete.active_slot==0 and after_delete.active_store()==null,"Stale registry backup cannot enable writing into a deleted profile")
	_check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(deleted.root_path+"/slot_1")),"Registry recovery never recreates the archived profile directory")
	for failure in failures:push_error(failure)
	print("SLOT_FAILURES_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	print("TEST_COMPLETE test_save_slots_failures.gd")
	quit(0 if failures.is_empty() else 1)
