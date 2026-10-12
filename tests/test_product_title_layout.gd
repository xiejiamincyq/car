extends SceneTree
## Real Main UI with explicitly synthetic layout records; never a player save.
const MainScene = preload("res://scenes/main.tscn")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")
const Store = preload("res://scripts/save_store.gd")
class MemoryStore extends Store:
	func load_data() -> Dictionary: return Store.default_data()
	func save_data(_data: Dictionary) -> bool: return true
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not failures.has(message): failures.append(message)

func _tab() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := "" if args.is_empty() else args[0]
	if args.size() > 1 or (not folder.is_empty() and (DisplayServer.get_name() == "headless" or DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) != OK)):
		quit(2); return
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main._configure_persistence(MemoryStore.new(), true)
	main.set_process(false)
	var content: VBoxContainer = main.title_screen.get_node("Center/Card/Content")
	var card: PanelContainer = content.get_parent()
	var buttons: Array[Button] = []
	for name in ["StartButton", "DifficultyButton", "LeaderboardButton", "SaveButton", "SettingsButton", "ControlsButton", "QuitButton"]:
		_check((content.find_child(name,true,false) != null), "Title includes menu action "+name)
		if (content.find_child(name,true,false) != null): buttons.append(content.find_child(name,true,false))
	for dimensions in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = dimensions
		if not folder.is_empty(): DisplayServer.window_set_size(dimensions)
		for language in ["zh", "en"]:
			main._set_language_preference(language)
			for record_count in [0,5]:
				main.persistence_notice_key = ""
				main._update_persistence_notice()
				main.save_data.top_scores = []
				for index in record_count:
					main.save_data.top_scores.append({"score":999999-index,"distance":3999.0,"difficulty":index%3})
				main._update_scoreboards()
				await process_frame
				await process_frame
				var label: Label = content.get_node("Title")
				_check(card.get_global_rect().end.x <= dimensions.x*0.55, "Title menu leaves the right-hand road visible")
				_check(not label.visible and content.has_node("Logo") and content.get_node("Logo").is_visible_in_tree(), "Title identity is a graphical road-sign logo, not plain label text")
				_check(main.title_screen.get_global_rect().encloses(card.get_global_rect()), "Title card fits both resolutions and record states")
				_check(not main.title_best_scores.is_visible_in_tree() and main.title_best_scores.text == main._format_top_scores(main.save_data.top_scores), "All records remain available behind the leaderboard action, not on title")
				for child in content.get_children():
					if child is Control and child.visible:
						_check(card.get_global_rect().encloses(child.get_global_rect()), "Visible title content stays inside its card")
				for name in ["Subtitle", "Goal", "Version"]:
					_check(not content.find_child(name,true,false).visible, "Redundant explanations stay hidden")
				buttons[0].grab_focus()
				for index in buttons.size():
					await _tab()
					_check(buttons[(index+1)%buttons.size()].has_focus(), "Real Tab events traverse all seven menu actions and wrap")
				if not folder.is_empty():
					await RenderingServer.frame_post_draw
					_check(root.get_texture().get_image().save_png(folder.path_join("title-%s-%d-records%d.png" % [language,dimensions.y,record_count])) == OK, "Actual viewport capture succeeds")
				buttons[2].pressed.emit()
				await process_frame
				await process_frame
				var board: Control = main.leaderboard_screen
				var board_card: Control = board.get_node("Center/Card")
				_check(board.visible and not main.title_screen.visible and board.get_global_rect().encloses(board_card.get_global_rect()), "Leaderboard panel fits both resolutions")
				_check(main.title_best_scores.text == main._format_top_scores(main.save_data.top_scores), "Leaderboard retains all five records or empty state")
				_check(board_card.get_global_rect().encloses(main.title_best_scores.get_global_rect()), "Leaderboard records do not overflow")
				_check(board.get_node("Center/Card/Content/BackButton").has_focus(), "Leaderboard opens with keyboard Back focus")
				if not folder.is_empty():
					await RenderingServer.frame_post_draw
					_check(root.get_texture().get_image().save_png(folder.path_join("board-%s-%d-records%d.png" % [language,dimensions.y,record_count])) == OK, "Leaderboard viewport capture succeeds")
				var escape := InputEventKey.new()
				escape.keycode = KEY_ESCAPE
				escape.pressed = true
				Input.parse_input_event(escape)
				Input.flush_buffered_events()
				main._process(0.01)
				_check(main.title_screen.visible and not board.visible and buttons[2].has_focus(), "Actual Escape returns to the leaderboard action")
				var escape_release := InputEventKey.new()
				escape_release.keycode = KEY_ESCAPE
				escape_release.pressed = false
				Input.parse_input_event(escape_release)
				Input.flush_buffered_events()
				buttons[3].pressed.emit()
				await process_frame
				_check(main.persistence_notice.visible and main.persistence_notice_key == "persistence.saved", "Manual save success has visible localized feedback")
				if not folder.is_empty():
					await RenderingServer.frame_post_draw
					_check(root.get_texture().get_image().save_png(folder.path_join("saved-%s-%d-records%d.png" % [language,dimensions.y,record_count])) == OK, "Save feedback viewport capture succeeds")
	var shade: ColorRect = main.menu_backdrop.get_node("MenuShade")
	_check(is_equal_approx(shade.color.a,0.22), "Scenic title retains the lighter backdrop")
	main._show_settings()
	_check(is_equal_approx(shade.color.a,0.48), "Settings restore the readable dark backdrop")
	main._close_submenu()
	_check(is_equal_approx(shade.color.a,0.22) and buttons[4].has_focus(), "Returning from settings restores title backdrop and focus")
	var playbacks := AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self,playbacks), "Audio teardown completes")
	for failure in failures: push_error("TITLE_LAYOUT "+failure)
	print("TITLE_LAYOUT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"real Main, two languages and resolutions, empty/full synthetic record fixtures, actual key events; no formal save"}))
	print("TEST_COMPLETE test_product_title_layout.gd")
	quit(0 if failures.is_empty() else 1)
