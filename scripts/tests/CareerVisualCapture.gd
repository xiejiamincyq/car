extends SceneTree
## Native UI-only synthetic fixtures; never the normal player entry or profile.
const Scene = preload("res://scenes/main.tscn")
const Store = preload("res://scripts/save_store.gd")
const Progress = preload("res://scripts/progression.gd")
const Teardown = preload("res://tests/support/audio_teardown.gd")
var issues: Array[String] = []
var destination := ""
var prefix := ""
func _init() -> void:call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=4:quit(2);return
	destination=args[0]
	var locale := args[1]
	var width := int(args[2])
	var height := int(args[3])
	prefix=locale+"-"+str(height)
	DisplayServer.window_set_size(Vector2i(width,height))
	root.size=Vector2i(width,height)
	await process_frame
	var main = Scene.instantiate()
	root.add_child(main)
	main.set_process(false)
	main._set_language_preference(locale)
	main.save_data=Store.default_data()
	for index in 17:
		main.save_data=Progress.record_run(main.save_data,{"score":1234567-index,"difficulty":index%3,
			"distance":1200.0,"survival":20.0,"overtakes":1,"near_misses":0,"stage":1,
			"track_id":&"freight_harbor" if index%2 else &"neon_coast","cleared":index%2==0},"2026-10-13").data
	main._update_scoreboards()
	await _capture(main,"title")
	main._show_leaderboard()
	await _capture(main,"career-first")
	main._change_career_page(3)
	await _capture(main,"career-last")
	main._close_submenu()
	main.save_data.run_history=[]
	main._show_leaderboard()
	await _capture(main,"career-legacy")
	main._close_submenu()
	main._open_tour_map()
	main._open_vehicle_select()
	await _capture(main,"garage")
	main.vehicle_select_screen.hide()
	main.title_screen.hide()
	main.run.phase=main.RunState.Phase.GAME_OVER
	main.run.score=9876543
	main.run.distance=100.0
	main.run.elapsed_seconds=12.0
	main.result_persisted=false
	main._update_hud()
	await _capture(main,"failed")
	main._return_to_title()
	main._reset_run(611)
	main.run.phase=main.RunState.Phase.RUN_CLEAR
	main.run.score=1234567
	main.run.elapsed_seconds=60.0
	main.run.overtakes=12
	main.run.coins=30
	main.coin_director.generated_coin_count=60
	main.run.distance=main.run.progression.finish_distance
	main.result_persisted=false
	main._update_hud()
	await _capture(main,"clear")
	main._return_to_title()
	main.title_screen.hide()
	var records := [{"status":&"primary","data":main.save_data},{"status":&"missing","data":{}},
		{"status":&"invalid","data":{}},{"status":&"backup","data":main.save_data}]
	main.save_slots_screen.present(records,1,locale,true)
	main.save_slots_screen.open()
	await _capture(main,"slots")
	main.save_slots_screen.cards[0].copy.pressed.emit()
	await _capture(main,"copy")
	var refs := Teardown.capture(main)
	main.audio_director.shutdown()
	main.free()
	if not await Teardown.wait_for_release(self,refs):issues.append("Audio teardown")
	print("CAREER_VISUAL_COMPLETE ",JSON.stringify({"prefix":prefix,"images":9,"issues":issues}))
	quit(0 if issues.is_empty() else 1)
func _capture(main: Node,label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	for control in main.find_children("*","Control",true,false):
		if control.is_visible_in_tree() and control is BaseButton:
			if not main.get_viewport_rect().grow(1).encloses(control.get_global_rect()):issues.append(label+":"+String(control.name))
	var path := destination.path_join(prefix+"-"+label+".png")
	if root.get_texture().get_image().save_png(path)!=OK:issues.append("PNG "+label)
	print("CAREER_CAPTURE "+path)
