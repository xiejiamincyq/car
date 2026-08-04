extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main._start_new_run()
	main.run.tick(3.0, 0.0, main.GameConfig.MAX_SPEED)
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.content_scale_size = size
		main._update_hud()
		await process_frame
		var panel: Control = main.get_node("CanvasLayer/RaceHUD/Panel")
		var hud: Control = main.get_node("CanvasLayer/RaceHUD")
		assert(panel.get_global_rect().size.y > 0.0, "HUD panel must receive an actual layout rect")
		for label_name in ["Speed", "ControlsHint", "Score", "Fuel", "RunStatus"]:
			var label: Control = main.get_node("CanvasLayer/RaceHUD/Rows/" + label_name)
			assert(hud.get_global_rect().encloses(label.get_global_rect()), "%s HUD label must fit at %s" % [label_name, size])
			assert(panel.get_global_rect().encloses(label.get_global_rect()), "%s must not be clipped by its panel at %s" % [label_name, size])
	root.content_scale_size = Vector2i(1280, 720)
	main.free()
	quit()
