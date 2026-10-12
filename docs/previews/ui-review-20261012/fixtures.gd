extends RefCounted
## Explicitly synthetic in-memory data, using real Main menu and rating paths.
static func prepare(main, state: String) -> void:
	main.save_data.top_scores = [{"score":24800,"difficulty":1,"distance":3200.0},{"score":19320,"difficulty":2,"distance":3000.0},{"score":12700,"difficulty":0,"distance":2600.0}]
	for record in main.save_data.top_scores: record.date = "2026-10-12"
	main._update_scoreboards()
	match state:
		"tour": main._open_tour_map()
		"garage":
			main._open_tour_map(); main._open_vehicle_select()
		"settings": main._show_settings()
		"controls": main._show_controls()
		"board", "empty_board":
			if state == "empty_board": main.save_data.top_scores = []
			main._show_leaderboard()
		"pause", "confirm", "clear", "failed", "hud", "warning", "countdown":
			main.title_screen.hide()
			main.run.phase = main.RunState.Phase.RUNNING
			main.run.distance = 1800
			main.run.score = 24800
			main.run.coins = 87
			main.drive.speed = 610
			main.run.fuel = 64
			main.integrity.current = 76
			main._update_hud()
			if state in ["pause", "confirm"]:
				main._pause_run()
				if state == "confirm": main._request_title()
			elif state in ["clear", "failed"]:
				main.run.elapsed_seconds = 56
				main.run.overtakes = 19
				main.run.collisions = 2
				main.coin_director.generated_coin_count = 120
				main.run.phase = main.RunState.Phase.RUN_CLEAR if state == "clear" else main.RunState.Phase.GAME_OVER
				if state == "clear": main.run.distance = main.run.progression.finish_distance
				main.run.failure_reason = &"integrity"
				main.result_persisted = false
				main._update_hud()
			elif state == "warning":
				main.run.fuel = 10; main.integrity.current = 25
				main.run.score = 9999999; main.run.coins = 9999
				main.feedback.tick(0.2,main.run.fuel,main.run.difficulty_stage)
				main._update_hud()
			elif state == "countdown":
				main.run.phase = main.RunState.Phase.COUNTDOWN
				main.run.countdown_remaining = 2
				main._update_hud()
			if state in ["hud","warning"]:
				var v = main.traffic.acquire_vehicle(main.TrafficDirector.Kind.STEADY_SLOW,0,360,200)
				main.traffic.vehicles.assign([v])
				main.queue_redraw(); main.roadside_renderer.queue_redraw()
