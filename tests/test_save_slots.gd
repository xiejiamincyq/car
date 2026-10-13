extends SceneTree
const Store = preload("res://scripts/save_store.gd")
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _run() -> void:
	if not ResourceLoader.exists("res://scripts/save_slots.gd"):
		_check(false,"Four-slot storage implementation is required")
		_finish();return
	var Slots = load("res://scripts/save_slots.gd")
	var fixture := "res://tmp/save-slots-test-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	var legacy_path := fixture+"/legacy.cfg"
	var legacy := Store.default_data()
	legacy.career.runs=41
	legacy.settings.music_volume=0.35
	_check(Store.new(legacy_path).save_data(legacy),"Write isolated original-format fixture")
	var original_hash := FileAccess.get_sha256(legacy_path)
	var slots = Slots.new(fixture+"/profiles",legacy_path)
	_check(slots.initialize(),"Initialize four slots and migrate valid old data")
	_check(slots.slot_count()==4 and slots.active_slot==1,"Exactly four slots, first migration activates slot1")
	_check(slots.slot_info(1).data.career.runs==41,"Migration preserves real career")
	_check(FileAccess.get_sha256(legacy_path)==original_hash,"Migration does not rewrite original save")
	for index in [2,3,4]:_check(slots.slot_info(index).status==&"missing","Other slots stay empty")
	_check(not slots.activate_slot(0) and not slots.activate_slot(5),"Reject invalid slot indexes")
	_check(slots.activate_slot(2),"Load/create a second independent profile")
	var second := Store.default_data()
	second.career.runs=7
	second.settings.music_volume=0.85
	_check(slots.active_store().save_data(second),"Existing SaveStore writes only the active slot")
	_check(slots.slot_info(1).data.career.runs==41 and slots.slot_info(2).data.career.runs==7,"Slot writes never cross into another career")
	var reopened = Slots.new(fixture+"/profiles",legacy_path)
	_check(reopened.initialize() and reopened.active_slot==2,"Restart remembers active slot")
	_check(reopened.active_store().load_data().settings.music_volume==0.85,"Settings travel with selected profile")
	_check(reopened.slot_info(1).data.career.runs==41,"Restart never remigrates over a profile")
	_check(FileAccess.get_sha256(legacy_path)==original_hash,"Original save still intact after restart")
	_check(slots.has_method("copy_slot") and slots.has_method("delete_slot"),"Every slot supports copying and recoverable deletion")
	if slots.has_method("copy_slot") and slots.has_method("delete_slot"):
		_check(not slots.copy_slot(1,1),"Self-copy rejected")
		_check(slots.copy_slot(1,3),"Copy into an empty slot")
		_check(slots.slot_info(3).data==slots.slot_info(1).data and slots.active_slot==2,"Copy preserves source and does not switch current slot")
		_check(not slots.copy_slot(1,2),"Occupied target cannot be overwritten without confirmation")
		_check(slots.slot_info(2).data.career.runs==7,"Rejected copy preserves target")
		_check(slots.copy_slot(1,2,true),"Explicitly confirmed overwrite succeeds")
		_check(slots.slot_info(2).data.career.runs==41 and slots.active_slot==2,"Overwriting current slot keeps its identity with new progress")
		_check(not slots.delete_slot(3),"Deletion requires explicit confirmation")
		_check(slots.slot_info(3).status==&"primary","Cancelled deletion does not alter data")
		_check(slots.delete_slot(3,true),"Delete inactive slot recoverably")
		_check(slots.slot_info(3).status==&"missing" and slots.active_slot==2,"Deleted slot is empty and current slot is unchanged")
		_check(FileAccess.file_exists(slots.last_archive_path+"/save.cfg"),"Removed profile remains recoverable")
		_check(slots.delete_slot(2,true) and slots.active_slot==0,"Deleting current slot leaves no writable active memory")
		var after_delete = Slots.new(fixture+"/profiles",legacy_path)
		_check(after_delete.initialize() and after_delete.active_slot==0 and after_delete.slot_info(2).status==&"missing","Restart does not resurrect the deleted current slot")
		_check(slots.delete_slot(1,true),"Original imported slot can be removed without deleting original legacy source")
		var after_all_delete = Slots.new(fixture+"/profiles",legacy_path)
		_check(after_all_delete.initialize() and after_all_delete.slot_info(1).status==&"missing","Deleted migration is not repeated even when all slots are empty")
		_check(FileAccess.get_sha256(legacy_path)==original_hash,"Copy/delete never modify the legacy source")
	_finish()
func _finish() -> void:
	print("SAVE_SLOTS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	print("TEST_COMPLETE test_save_slots.gd")
	quit(0 if failures.is_empty() else 1)
