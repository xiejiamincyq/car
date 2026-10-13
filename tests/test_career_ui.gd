extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Store = preload("res://scripts/save_store.gd")
const Text = preload("res://scripts/game_text.gd")
const Teardown = preload("res://tests/support/audio_teardown.gd")
class FailedWrite extends Store:
	var fail := true
	func _promote_temp_file(temporary_path: String,target_path: String) -> Error:
		return ERR_CANT_CREATE if fail else super._promote_temp_file(temporary_path,target_path)
var failures: Array[String]=[]
var checks := 0
func _init() -> void:call_deferred("_run")
func _run() -> void:
	var folder := "res://tmp/career-ui-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_check(DirAccess.make_dir_recursive_absolute(folder)==OK,"Isolated UI storage")
	var store := Store.new(folder+"/save.cfg")
	var main = Main.instantiate()
	root.add_child(main)
	main.set_process(false)
	main._configure_persistence(store,true)
	for index in 12:
		main._reset_run(611+index)
		main.run.phase=main.RunState.Phase.RUN_CLEAR if index%2==0 else main.RunState.Phase.GAME_OVER
		main.run.score=10000-index
		main.run.elapsed_seconds=25.0
		main.run.distance=main.run.progression.finish_distance if index%2==0 else 100.0
		main._update_hud()
		_check(Store.new(store.save_path).load_data().run_history.size()==index+1,"Win/loss is automatically on disk without manual save")
		main._update_hud()
		_check(main.save_data.run_history.size()==index+1,"Result repaint is idempotent")
		var score = main.result_screen.find_child("RunScore",true,false)
		_check(score is Label and score.visible and score.text.contains(str(10000-index)),"Every settlement prominently shows real run score")
	main._return_to_title()
	for language in ["zh","en"]:
		main._set_language_preference(language)
		_check(main.title_screen.find_child("LeaderboardButton",true,false).text==("生涯" if language=="zh" else "CAREER"),"Career button is localized")
		main._show_leaderboard()
		await process_frame
		var grid = main.leaderboard_screen.find_child("ScoreGrid",true,false)
		_check(grid.get_child_count()==24 and grid.get_child(5).text=="009989","First history page shows latest five, not highest five")
		if main.has_method("_change_career_page"):
			main._change_career_page(2)
			_check(grid.get_child_count()==12 and grid.get_child(5).text=="009999","Last page exposes older low-ranked entries")
			main._change_career_page(100)
			_check(grid.get_child_count()==12,"Page requests clamp to real history")
		else:_check(false,"All older entries are reachable by pagination")
		main._close_submenu()
	main._save_now()
	_check(main.persistence_notice_key=="persistence.saved","Manual save remains available")
	_check(Store.new(store.save_path).load_data()==main.save_data,"Manual save retains full history")
	var failed_store := FailedWrite.new(folder+"/failure.cfg")
	main._configure_persistence(failed_store,true)
	main._reset_run(921)
	main.run.phase=main.RunState.Phase.GAME_OVER
	main.run.score=55
	main._update_hud()
	_check(main.persistence_notice_key=="persistence.save_failed","Failed automatic save is not reported as success")
	_check(main.save_data.run_history.size()==1,"Failed save retains settled history in memory")
	main._update_hud()
	_check(main.save_data.run_history.size()==1,"Failed save does not double-settle on repaint")
	main._return_to_title()
	failed_store.fail=false
	main._save_now()
	_check(Store.new(failed_store.save_path).load_data().run_history.size()==1,"Manual retry stores one copy of the failed automatic settlement")
	_check(Text.get_text("slots.current","zh",[1])=="当前存档 1","Current slot message is concise")
	_check(Text.get_text("slots.confirm_copy","zh",[1,2]).contains("源存档保留不变"),"Copy keeps source-preservation confirmation")
	var refs := Teardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	_check(await Teardown.wait_for_release(self,refs),"Owned audio released")
	for failure in failures:push_error(failure)
	print("CAREER_UI ",JSON.stringify({"checks":checks,"failures":failures}))
	print("TEST_COMPLETE test_career_ui.gd")
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok and not failures.has(message):failures.append(message)
