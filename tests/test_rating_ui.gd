extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/save_store.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture := OS.get_cmdline_user_args().has("capture")
	root.content_scale_size = Vector2i.ZERO
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for language in ["zh", "en"]:
			for cleared in [true, false]:
				var main = MainScene.instantiate()
				root.add_child(main)
				main.set_process(false)
				main.persistence_enabled = false
				main.save_data = SaveStore.default_data()
				main.language = language
				main._apply_localized_texts()
				main.high_contrast_enabled = language == "en"
				main._reset_run(611)
				main.run.phase = main.RunState.Phase.RUN_CLEAR if cleared else main.RunState.Phase.GAME_OVER
				main.run.elapsed_seconds = 66.0
				main.run.distance = 3200.0
				main.run.overtakes = 11
				main.run.coins = 54
				main.run.score = 7200
				main._update_hud()
				for frame in range(4): await process_frame
				var content: Control = main.get_node("CanvasLayer/ResultScreen/Center/Card/Content")
				var rating: Control = content.get_node("RatingCard")
				assert(rating.headline.text.contains("92 / 100") if cleared else not rating.headline.text.contains("/ 100"))
				assert(rating.cells.size() == 4)
				assert(rating.cells[3].points.text == ("18 / 20" if cleared else "54"))
				assert(main.result_screen.get_global_rect().encloses(content.get_parent().get_global_rect()), "Result card must fit the viewport")
				for button_name in ["ReplayButton", "TitleButton"]:
					var button: Button = content.get_node(button_name)
					assert(main.result_screen.get_global_rect().encloses(button.get_global_rect()))
				assert(content.get_node("ReplayButton").has_focus(), "Keyboard focus must start on replay")
				if capture:
					await RenderingServer.frame_post_draw
					assert(root.get_texture().get_image().save_png("res://tmp/rating-%s-%s-%s.png" % [resolution.x, language, "clear" if cleared else "failed"]) == OK)
				main.free()
	quit()
