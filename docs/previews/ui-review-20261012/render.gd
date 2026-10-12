extends SceneTree
const MainScene = preload("res://scenes/main.tscn")
const Store = preload("res://scripts/save_store.gd")
const Teardown = preload("res://tests/support/audio_teardown.gd")
const Fixtures = preload("res://docs/previews/ui-review-20261012/fixtures.gd")
const PreviewSkin = preload("res://docs/previews/ui-review-20261012/skin.gd")
const Hud = preload("res://docs/previews/ui-review-20261012/hud.gd")
const STATES := ["title","garage","tour","settings","clear","hud","board"]
class MemoryStore extends Store:
	func load_data() -> Dictionary: return Store.default_data()
	func save_data(_data: Dictionary) -> bool: return true
var paths: Array[String] = []
var errors: Array[String] = []
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or DirAccess.dir_exists_absolute(args[0]) or DisplayServer.get_name() == "headless": quit(2); return
	if DirAccess.make_dir_recursive_absolute(args[0]) != OK: quit(3); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions; DisplayServer.window_set_size(dimensions)
		await process_frame
		for locale in ["zh","en"]:
			for state in STATES:
				var main = MainScene.instantiate()
				root.add_child(main); main.set_process(false)
				main._configure_persistence(MemoryStore.new(),true)
				main._set_language_preference(locale)
				Fixtures.prepare(main,state)
				PreviewSkin.apply(main,state)
				if state == "hud":
					main.race_hud.hide()
					var hud := Hud.new(); hud.main = main
					main.get_node("CanvasLayer").add_child(hud)
				var caption := PreviewSkin.label("设计预览" if locale == "zh" else "DESIGN PREVIEW",14)
				caption.position = Vector2(1050,691); caption.size = Vector2(206,25)
				caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				caption.modulate.a = 0.70
				caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
				main.get_node("CanvasLayer").add_child(caption)
				await process_frame; await process_frame
				for name in ["TitleScreen","VehicleSelectScreen","TourMapScreen","SettingsScreen","ResultScreen","LeaderboardScreen"]:
					var screen: Control = main.get_node("CanvasLayer/"+name)
					if screen.is_visible_in_tree() and not Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(screen.get_node("Center/Card").get_global_rect()): errors.append("Overflow: "+name+" "+locale)
				await RenderingServer.frame_post_draw
				var path := args[0].path_join("%s-%s-%d.png" % [state,locale,dimensions.y])
				if root.get_texture().get_image().save_png(path) != OK: errors.append("Capture: "+path)
				else: paths.append(path)
				var audio := Teardown.capture(main)
				main.audio_director.shutdown(); main.queue_free()
				await process_frame
				if not await Teardown.wait_for_release(self,audio): errors.append("Audio teardown")
	print("UI_PREVIEW_COMPLETE ",JSON.stringify({"images":paths.size(),"errors":errors,"scope":"Proposed in-memory styling of actual Main UI; synthetic metrics, not production implementation or human acceptance"}))
	quit(0 if paths.size() == 28 and errors.is_empty() else 1)
