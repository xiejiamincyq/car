extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main._start_new_run()
	main.run.tick(3.0, 0.0, main.GameConfig.MAX_SPEED)
	for _event in range(4):
		main.run.award_pass(80, false)
	main.run.tick(1.0, 0.0, main.GameConfig.MAX_SPEED)
	main._update_hud()
	assert(main.run_status_label.text.contains("COMBO x2 1.5s"), "The HUD must show the live multiplier and remaining combo window")
	main.run.coins = 7
	main._update_hud()
	assert(main.coin_label.text.contains("07"), "The HUD must expose a compact zero-padded coin counter")
	main.feedback.flashing_enabled = false
	main.feedback.tick(0.0, 10.0, 1)
	main._update_hud()
	assert(main.fuel_label.text.contains("燃油危险"), "Critical fuel must remain understandable without relying on colour or flashing")
	assert(main.fuel_label.get_theme_color("font_color") == Color.WHITE, "Critical warning tint must not be multiplied by the old green font colour")
	assert(main.fuel_gauge.modulate.r > main.fuel_gauge.modulate.g, "Critical fuel bar must be visibly red")
	main.run.progression.finish_distance = 3400.0
	main.run.distance = 1700.0
	main._update_hud()
	assert(is_equal_approx(main.progress_gauge.value, 50.0), "Distance bar must use the selected course finish, not the global default")
	assert(main.feedback_banner.visible and main.feedback_banner.text == "赛段 2", "A stage change must show an explicit HUD banner")
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.content_scale_size = size
		main._update_hud()
		await process_frame
		var panel: Control = main.get_node("CanvasLayer/RaceHUD/Panel")
		var hud: Control = main.get_node("CanvasLayer/RaceHUD")
		assert(hud.position.is_equal_approx(Vector2.ZERO), "The HUD must sit flush against the top-left viewport corner")
		assert(is_equal_approx(panel.color.a, 0.70), "The HUD background must use seventy-percent opacity")
		assert(main.speed_label.get_theme_font_size("font_size") >= 32 and main.speed_label.get_theme_constant("outline_size") >= 3, "Primary HUD numbers must be larger and outlined")
		assert(panel.get_global_rect().size.y > 0.0, "HUD panel must receive an actual layout rect")
		assert(not main.controls_hint_label.visible and main.controls_hint_label.text.is_empty(), "Driving HUD must remove key hints and seed text")
		assert(main.speed_label.get_global_rect().position.y > size.y * 0.5, "Speed instrument must be bottom-left")
		assert(main.score_label.get_global_rect().position.x > size.x * 0.7, "Score must move to top-right")
		assert(main.coin_label.get_global_rect().position.x > size.x * 0.7, "Coins must move to top-right")
		assert(main.race_hud.get_node("IntegrityGauge").value == main.integrity.current, "Hull bar must expose actual integrity")
		assert(not main.score_label.text.contains("距离") and not main.score_label.text.contains("DIST"), "Distance must not remain coupled to score")
		for label_name in ["Speed", "Score", "Fuel", "OverdriveLabel", "RunStatus"]:
			var label: Control = main.get_node("CanvasLayer/RaceHUD/Rows/" + label_name)
			assert(hud.get_global_rect().encloses(label.get_global_rect()), "%s HUD label must fit at %s" % [label_name, size])
		var coin_label: Control = main.get_node("CanvasLayer/RaceHUD/CoinLabel")
		assert(hud.get_global_rect().encloses(main.integrity_label.get_global_rect()), "Integrity indicator must fit inside the HUD")
		assert(hud.get_global_rect().encloses(coin_label.get_global_rect()), "Coin counter must fit inside the HUD at %s" % size)
		var overdrive_gauge: Control = main.get_node("CanvasLayer/RaceHUD/Rows/OverdriveGauge")
		assert(hud.get_global_rect().encloses(overdrive_gauge.get_global_rect()), "Overdrive meter must fit inside the HUD at %s" % size)
		main.run.phase = main.RunState.Phase.PAUSED
		main._update_hud()
		assert(main.run_status_label.text.contains(main._phase_text()), "Pause state must remain visible in the top-left status strip")
		main.run.end()
		main._update_hud()
		await process_frame
		var result_screen: Control = main.get_node("CanvasLayer/ResultScreen")
		for button_name in ["ReplayButton", "TitleButton"]:
			var button: Control = main.get_node("CanvasLayer/ResultScreen/Center/Card/Content/" + button_name)
			assert(result_screen.get_global_rect().encloses(button.get_global_rect()), "%s must remain fully visible at %s" % [button_name, size])
		main._replay_run()
	root.content_scale_size = Vector2i(1280, 720)
	main.free()
	quit()
