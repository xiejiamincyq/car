extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/save_store.gd")
const AudioTeardown = preload("res://tests/support/audio_teardown.gd")

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
				main.run.elapsed_seconds = main.TrackCatalog.get_by_id(&"neon_coast").rating_targets.time * 1.1
				main.run.distance = 3200.0
				if not cleared:
					main.run.distance = main.run.progression.finish_distance * 0.5
					main.run.elapsed_seconds = 30.0
				main.run.overtakes = 11
				main.run.coins = 54
				main.coin_director.generated_coin_count = 60
				main.run.score = 7200
				main._update_hud()
				if main.result_summary.text.contains("种子") or main.result_summary.text.to_upper().contains("SEED"):
					push_error("Player-facing result summaries must omit debug seeds in both languages and outcomes")
					quit(1)
					return
				for frame in range(4): await process_frame
				var content: Control = main.get_node("CanvasLayer/ResultScreen/Center/Card/Content")
				var rating: Control = content.get_node("RatingCard")
				assert(rating.headline.text.contains("94 / 100") if cleared else rating.headline.text.contains("/ 100"))
				if not cleared:
					assert(rating.best_label.text.contains("未完赛" if language == "zh" else "NOT FINISHED"))
					assert(rating.best_label.text.contains("50%"))
					assert(main.last_run_rating.total == 49)
				assert(rating.cells.size() == 4)
				assert(rating.cells[3].points.text.contains("/ 20"))
				assert(main.result_screen.get_global_rect().encloses(content.get_parent().get_global_rect()), "Result card must fit the viewport")
				for button_name in ["ReplayButton", "TitleButton"]:
					var button: Button = content.get_node(button_name)
					assert(main.result_screen.get_global_rect().encloses(button.get_global_rect()))
				assert(content.get_node("ReplayButton").has_focus(), "Keyboard focus must start on replay")
				if capture:
					await RenderingServer.frame_post_draw
					assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tmp/rating-%s-%s-%s.png" % [resolution.x, language, "clear" if cleared else "failed"])) == OK)
				var refs := AudioTeardown.capture(main)
				main.audio_director.shutdown()
				main.free()
				assert(await AudioTeardown.wait_for_release(self, refs))
	print("TEST_COMPLETE test_rating_ui.gd")
	quit()
