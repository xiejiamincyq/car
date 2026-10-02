extends SceneTree
## Synthetic memory-only persistence failures through actual Main UI.
const MainScene = preload("res://scenes/main.tscn")
const MemoryStore = preload("res://tests/test_save_feedback.gd").MemoryStore
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")

var output_dir := "res://tmp/persistence-notice-capture-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
var failures := 0
var samples: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Notice capture requires actual rendering, not --headless")
		quit(2)
		return
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir)) == OK, "capture directory created")
	print("NOTICE_CAPTURE synthetic=true memory_only=true formal_save_io=false output=", ProjectSettings.globalize_path(output_dir))
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(size)
		await process_frame
		await process_frame
		for locale in ["zh", "en"]:
			for scenario in ["settings", "running", "result"]:
				await _sample(size, locale, scenario)
			if size.x == 1280:
				for scenario in ["tour", "garage", "controls", "pause", "confirm"]:
					await _sample(size, locale, scenario)
		# Backup representatives: Chinese at 720p, English at 1080p.
		await _sample(size, "zh" if size.x == 1280 else "en", "title_backup")
	var manifest := FileAccess.open(output_dir + "/checks.json", FileAccess.WRITE)
	_check(manifest != null, "manifest opened")
	if manifest != null:
		manifest.store_string(JSON.stringify({"synthetic": true, "memory_only": true, "samples": samples}, "\t"))
		manifest.close()
	print("NOTICE_CAPTURE_COMPLETE samples=%d failures=%d output=%s" % [samples.size(), failures, ProjectSettings.globalize_path(output_dir)])
	quit(0 if failures == 0 else 1)

func _sample(size: Vector2i, locale: String, scenario: String) -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main) # Not current_scene; production SaveStore is never read.
	main.set_process(false)
	_check(current_scene != main and not main.persistence_enabled, "isolated Main starts without formal persistence")
	var store := MemoryStore.new()
	store.fixture.settings.language = locale
	store.fixture_status = &"backup" if scenario == "title_backup" else &"primary"
	main._configure_persistence(store, true) # This enabled store has NO disk implementation.
	main.audio_director.shutdown()
	if scenario == "settings":
		main._show_settings()
	elif scenario == "controls":
		main._show_controls()
	elif scenario in ["tour", "garage"]:
		main._open_tour_map()
		if scenario == "garage":
			main._open_vehicle_select()
	elif scenario in ["running", "result", "pause", "confirm"]:
		main.run.phase = main.RunState.Phase.RUNNING
		main.run.distance = 1800.0
		main.drive.speed = 240.0
		main.run.score = 24800
		main.run.coins = 30
		main._update_hud()
		_hide_menus(main)
		if scenario == "result":
			main.run.phase = main.RunState.Phase.GAME_OVER
			main.run.elapsed_seconds = 60.0
			main.result_persisted = false
			main.result_screen.show()
			main._update_result_labels()
			main.result_screen.get_node("Center/Card/Content/ReplayButton").grab_focus()
		elif scenario in ["pause", "confirm"]:
			main._pause_run()
			if scenario == "confirm":
				main._request_restart()
	await process_frame
	var focus_before: Control = root.gui_get_focus_owner()
	var expected_save_calls: int = store.save_calls + (0 if scenario == "title_backup" else 1)
	if scenario == "result":
		main._persist_result_once()
		main._update_hud()
	elif scenario != "title_backup":
		main._save_preferences()
	main.queue_redraw()
	main.roadside_renderer.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var label: Label = main.persistence_notice
	var rect := label.get_global_rect()
	var viewport_rect: Rect2 = main.get_viewport_rect()
	var overlaps: Array[String] = []
	# Only leaf buttons and actual HUD labels/bars, never full-screen containers.
	for button in main.find_children("*", "BaseButton", true, false):
		if button is Control and button.is_visible_in_tree() and rect.intersects(button.get_global_rect()):
			overlaps.append(String(button.get_path()))
	for leaf in main.find_children("*", "Control", true, false):
		if leaf == label or not leaf.is_visible_in_tree():
			continue
		if leaf is Label and leaf.text.is_empty():
			continue
		if (leaf is Label or leaf is RichTextLabel or leaf is Range) and rect.intersects(leaf.get_global_rect()):
			overlaps.append(String(leaf.get_path()))
	# The garage chart draws radar labels/bars directly rather than child Labels.
	var chart: Control = main.vehicle_select_screen.performance_chart
	if chart.is_visible_in_tree() and rect.intersects(chart.get_global_rect()):
		overlaps.append(String(chart.get_path()) + " (custom-drawn radar/text)")
	var contained := viewport_rect.encloses(rect)
	var focus_unchanged := root.gui_get_focus_owner() == focus_before
	var text_visible := label.is_visible_in_tree() and not label.text.is_empty() and label.get_visible_line_count() >= label.get_line_count()
	var label_name := "%dx%d_%s_%s" % [size.x, size.y, locale, scenario]
	_check(contained, "notice is inside viewport: " + label_name)
	_check(focus_unchanged and label.focus_mode == Control.FOCUS_NONE and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "notice does not capture focus or mouse: " + label_name)
	_check(text_visible, "all notice lines are visible: " + label_name)
	_check(overlaps.is_empty(), "notice overlaps no visible buttons or key HUD leaves: " + label_name + " " + str(overlaps))
	_check(store.load_calls == 1 and store.save_calls == expected_save_calls, "memory-store calls match scenario: " + label_name)
	var frame := root.get_texture().get_image()
	_check(frame.get_size() == size, "actual viewport size: " + label_name)
	_check(frame.save_png(output_dir + "/" + label_name + ".png") == OK, "PNG saved: " + label_name)
	var pixel_scale := Vector2(frame.get_size()) / viewport_rect.size
	var state := {"file": label_name + ".png", "viewport_pixels": [frame.get_width(), frame.get_height()], "viewport_logical": [viewport_rect.size.x, viewport_rect.size.y], "notice_text": label.text, "notice_rect_logical": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "notice_rect_pixels": [rect.position.x * pixel_scale.x, rect.position.y * pixel_scale.y, rect.size.x * pixel_scale.x, rect.size.y * pixel_scale.y], "contained": contained, "focus_unchanged": focus_unchanged, "visible_lines": label.get_visible_line_count(), "total_lines": label.get_line_count(), "overlaps": overlaps, "scenario": scenario, "locale": locale, "load_calls": store.load_calls, "save_calls": store.save_calls, "frame": Engine.get_process_frames()}
	samples.append(state)
	print("NOTICE_FRAME ", JSON.stringify(state))
	var playbacks := AudioTeardown.capture(main)
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	_check(await AudioTeardown.wait_for_release(self, playbacks), "audio teardown: " + label_name)

func _hide_menus(main: Node) -> void:
	for name in ["menu_backdrop", "overlay_shade", "title_screen", "tour_map_screen", "vehicle_select_screen", "settings_screen", "controls_screen", "countdown_screen", "pause_screen", "result_screen", "confirmation_screen", "overlay_label"]:
		var control = main.get(name)
		if control != null:
			control.hide()
	main.race_hud.show()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("NOTICE_CAPTURE " + message)
