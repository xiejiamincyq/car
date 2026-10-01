extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const MENUS := ["TitleScreen", "TourMapScreen", "VehicleSelectScreen", "SettingsScreen", "ControlsScreen", "PauseScreen", "ResultScreen", "ConfirmationScreen"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	await process_frame
	for language in ["zh", "en"]:
		main._set_language_preference(language)
		main.run.phase = main.RunState.Phase.GAME_OVER
		main.run.distance = 1800.0
		main.run.elapsed_seconds = 60.0
		main.result_persisted = false
		main._persist_result_once()
		main._update_result_labels()
		for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = dimensions
			await process_frame
			await process_frame
			for name in MENUS:
				var screen: Control = main.get_node("CanvasLayer/"+name)
				screen.show()
				await process_frame
				await process_frame
				var card: PanelContainer = screen.get_node("Center/Card")
				var panel = card.get_theme_stylebox("panel") as StyleBoxFlat
				assert(panel != null and panel.bg_color.b > panel.bg_color.r and panel.border_width_top >= 2, "All menu cards need the shared navy/cyan presentation")
				assert(screen.get_global_rect().encloses(card.get_global_rect()), "%s must fit %s in %s" % [name, dimensions, language])
				for button in card.find_children("*", "Button", true, false):
					assert(card.get_global_rect().encloses(button.get_global_rect()), "Menu actions must remain inside the card")
					var focus = button.get_theme_stylebox("focus") as StyleBoxFlat
					assert(focus != null and focus.border_width_left >= 2, "Keyboard focus needs a clear, non-color-only outline")
					assert(button.get_theme_color("font_disabled_color") != button.get_theme_color("font_color"), "Disabled actions must be visually distinct")
				screen.hide()
	main.queue_free()
	await process_frame
	quit()
