extends SceneTree
## Approved coastal UI: real controls, isolated memory-only Main, no player save.
const MainScene = preload("res://scenes/main.tscn")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
var checks := 0
var failures: Array[String] = []
func _init() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main); main.set_process(false)
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		for locale in ["zh","en"]:
			main._set_language_preference(locale)
			await process_frame; await process_frame
			var content: Control = main.title_screen.get_node("Center/Card/Content")
			var grid := content.find_child("SecondaryActions",true,false)
			_check(grid is GridContainer and grid.columns == 2,"Approved title has two-column secondary actions")
			if grid is GridContainer:
				var leaderboard: Button = grid.find_child("LeaderboardButton",true,false)
				var save: Button = grid.find_child("SaveButton",true,false)
				_check(leaderboard != null and save != null,"Ranking and saving stay reachable in the title action grid")
				if leaderboard != null and save != null:
					_check(leaderboard.position.x < save.position.x and is_equal_approx(leaderboard.position.y,save.position.y),"Ranking and saving are side by side")
					_check(main.start_button.size.x > leaderboard.size.x and main.start_button.size.y >= 52,"Start has stronger visual hierarchy")
			_check(content.get_node("Logo").custom_minimum_size.y >= 160,"B crest has its approved clear header space")
			var garage = main.vehicle_select_screen
			garage.setup(main.save_data.tour, locale)
			main.title_screen.hide()
			garage.open()
			await process_frame
			for index in garage.vehicle_buttons.size():
				garage._select_index(index)
				garage.back_button.grab_focus()
				await process_frame
				var selected = garage.vehicle_buttons[index]
				_check(selected.find_child("Thumbnail",true,false) is TextureRect,"Every car has an undistorted thumbnail")
				_check(selected.text.contains("已选" if locale == "zh" else "SELECTED"),"Selection persists independently of action focus")
				_check(garage.back_button.has_focus(),"Selection remains marked with focus on Back")
				_check(garage.confirm_button.disabled == not garage.controller.can_confirm(),"Confirmation respects actual unlock state")
				_check(garage.get_global_rect().encloses(garage.get_node("Center/Card").get_global_rect()),"Garage fits supported dimensions")
			garage.hide()
			main.title_screen.show()
			for track in main.tour_map_screen.track_buttons:
				_check(track.find_child("Thumbnail",true,false) is TextureRect,"Every route has a fixed scenery preview")
			_check(main.settings_screen.find_child("DisplayActions",true,false) is GridContainer,"Display settings have their own group")
			main.save_data.top_scores = [{"score":1234567,"difficulty":2,"distance":4000.0}]
			main._update_scoreboards()
			var score_grid = main.leaderboard_screen.find_child("ScoreGrid",true,false)
			_check(score_grid is GridContainer,"Leaderboard uses comparable aligned columns")
			if score_grid is GridContainer:
				_check(score_grid.get_child_count() == 8 and score_grid.get_child(5).text == "1234567","Structured board displays truthful seven-digit scores")
			main._start_new_run()
			main.run.phase = main.RunState.Phase.RUNNING
			main.run.fuel = 12
			main._update_hud()
			var fuel_bar = main.race_hud.get_node_or_null("FuelBar")
			_check(fuel_bar is ProgressBar and is_equal_approx(fuel_bar.value,12),"Lower-left fuel bar reflects actual low fuel")
			if fuel_bar is ProgressBar:
				var fill: StyleBoxFlat = fuel_bar.get_theme_stylebox("fill")
				var effective_color: Color = fill.bg_color*fuel_bar.modulate
				_check(effective_color.r > effective_color.g*1.5,"Low-fuel bar stays red after style and modulation multiply")
			_check(not main.run_status_label.text.contains("COMBO"),"Idle combo explanation is absent")
			main._return_to_title()
	var audio := AudioTeardown.capture(main)
	main.audio_director.shutdown(); main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self,audio),"UI test releases owned audio")
	for failure in failures: push_error("UI_REFRESH "+failure)
	print("UI_REFRESH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	print("TEST_COMPLETE test_product_ui_refresh.gd")
	quit(0 if failures.is_empty() else 1)
