extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

const EXPECTED_ASSETS := {
	"res://assets/ui/hud_frame.png": Vector2i(512, 224),
	"res://assets/ui/event_plate.png": Vector2i(640, 96),
	"res://assets/ui/road_barrier.png": Vector2i(240, 80),
	"res://assets/ui/result_emblem.png": Vector2i(160, 160),
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for asset_path in EXPECTED_ASSETS:
		var texture := load(asset_path) as Texture2D
		assert(texture != null, "%s must import as a Texture2D" % asset_path)
		assert(texture.get_size() == Vector2(EXPECTED_ASSETS[asset_path]), "%s must keep its A3 UI canvas" % asset_path)
		var image := texture.get_image()
		assert(image.get_pixel(0, 0).a == 0.0, "%s must have a transparent corner" % asset_path)

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var constants: Dictionary = main.get_script().get_script_constant_map()
	for constant_name in ["HUD_FRAME_TEXTURE", "EVENT_PLATE_TEXTURE", "ROAD_BARRIER_TEXTURE", "RESULT_EMBLEM_TEXTURE"]:
		assert(constants.has(constant_name), "Main must preload %s" % constant_name)

	var hud_frame := main.get_node("CanvasLayer/RaceHUD/HUDFrame") as TextureRect
	var fuel_gauge := main.get_node("CanvasLayer/RaceHUD/Rows/FuelGauge") as ProgressBar
	var progress_gauge := main.get_node("CanvasLayer/RaceHUD/Rows/ProgressGauge") as ProgressBar
	var event_plate := main.get_node("CanvasLayer/EventPlate") as TextureRect
	var result_emblem := main.get_node("CanvasLayer/ResultScreen/Center/Card/Content/ResultEmblem") as TextureRect
	assert(hud_frame.texture != null and event_plate.texture != null and result_emblem.texture != null, "A3 decorative nodes must use their generated textures")

	main._start_new_run()
	main.run.tick(3.0, 0.0, main.GameConfig.MAX_SPEED)
	main.run.fuel = 42.0
	main.run.distance = main.GameConfig.RACE_FINISH_DISTANCE * 0.5
	main.feedback.announce_checkpoint(1, 12.0)
	main._update_hud()
	assert(is_equal_approx(fuel_gauge.value, 42.0), "Fuel gauge must mirror live fuel")
	assert(is_equal_approx(progress_gauge.value, 50.0), "Progress gauge must show percentage of the finish distance")
	assert(event_plate.visible == main.feedback_banner.visible, "Event plate must follow the event banner")

	main.run.phase = main.RunState.Phase.RUN_CLEAR
	main._update_hud()
	assert(main.result_screen.visible and result_emblem.visible, "The result emblem must decorate the result screen")
	main.queue_free()
	await process_frame
	quit()
