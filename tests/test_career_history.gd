extends SceneTree
const Store = preload("res://scripts/save_store.gd")
const Progress = preload("res://scripts/progression.gd")
const Slots = preload("res://scripts/save_slots.gd")
var failures: Array[String] = []
var checks := 0
func _init() -> void:
	var data := Store.default_data()
	if not data.has("run_history"):
		_check(false, "Each profile must own a full run history, separate from top five")
		_finish()
		return
	var original := data.duplicate(true)
	for index in 129:
		data = Progress.record_run(data, {"score":129-index,"difficulty":index%3,"distance":123.0,
			"survival":20.0,"overtakes":1,"near_misses":0,"stage":1,"track_id":&"neon_coast",
			"vehicle_id":&"pulse_gt","cleared":index%2==0}, "2026-10-13").data
	_check(original.run_history.is_empty(), "Settlement does not mutate caller snapshot")
	_check(data.run_history.size()==129 and data.top_scores.size()==5, "Low scores stay in history beyond any view page")
	_check(data.run_history[128].score==1 and data.run_history[128].run_number==129, "History stores actual scores in chronological order")
	_check(data.run_history[0].cleared and not data.run_history[1].cleared, "Wins and losses both have truthful entries")
	var folder := "res://tmp/career-history-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(folder)==OK,"Isolated fixture directory")
	var store := Store.new(folder+"/save.cfg")
	_check(store.save_data(data),"History saves through the protected store")
	_check(store.load_data()==data,"All entries round-trip, not just current page")
	var invalid := data.duplicate(true)
	invalid.run_history[0].score=-1
	_check(not store.save_data(invalid),"Invalid historical score cannot replace a good profile")
	_check(store.load_data()==data,"Rejected history leaves real saved data intact")
	invalid=data.duplicate(true)
	invalid.run_history[0].distance=NAN
	_check(not store.save_data(invalid),"Non-finite history values are invalid")
	var legacy := ConfigFile.new()
	_check(legacy.load(folder+"/save.cfg")==OK,"Read synthetic old profile")
	legacy.set_value("meta","version",6)
	legacy.erase_section("history")
	_check(legacy.save(folder+"/legacy.cfg")==OK,"Create a real v6 fixture")
	var migrated := Store.new(folder+"/legacy.cfg").load_data()
	_check(migrated.career.runs==129 and migrated.top_scores==data.top_scores,"v6 migration retains real totals and top scores")
	_check(migrated.run_history.is_empty(),"Missing old matches are not fabricated from top-five entries")
	var next: Dictionary = Progress.record_run(migrated,{"score":4,"difficulty":1,"distance":50.0,"survival":5.0,"overtakes":0,"near_misses":0,"stage":1},"2026-10-13").data
	_check(next.run_history.size()==1 and next.run_history[0].run_number==130,"Post-upgrade numbering continues the actual career")
	_check(next.run_history[0].track_id==&"neon_coast","Older callers without explicit track retain selected track")
	var slots := Slots.new(folder+"/profiles",folder+"/absent-legacy.cfg")
	_check(slots.initialize() and slots.active_store().save_data(data),"Profile one holds real full history")
	_check(slots.copy_slot(1,2) and slots.slot_info(2).data.run_history==data.run_history,"Profile copy includes all match entries")
	_check(slots.activate_slot(2),"History-bearing profile can be loaded")
	var copied: Dictionary=slots.active_store().load_data()
	copied=Progress.record_run(copied,{"score":0,"difficulty":0,"distance":0.0,"survival":1.0,"overtakes":0,"near_misses":0,"stage":1},"2026-10-13").data
	_check(slots.active_store().save_data(copied) and slots.slot_info(1).data.run_history.size()==129 and slots.slot_info(2).data.run_history.size()==130,"Appending in copied slot cannot change its source history")
	_finish()
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func _finish() -> void:
	for failure in failures:push_error(failure)
	print("CAREER_HISTORY ",JSON.stringify({"checks":checks,"failures":failures}))
	print("TEST_COMPLETE test_career_history.gd")
	quit(0 if failures.is_empty() else 1)
