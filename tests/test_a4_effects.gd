extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const FinishBurstTexture = preload("res://assets/effects/finish_burst.png")
const VehicleVisualAnimation = preload("res://scripts/vehicle_visual_animation.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(FinishBurstTexture.get_size() == Vector2(320, 320), "The finish burst must keep its frozen runtime canvas")
	assert(FinishBurstTexture.get_image().get_pixel(0, 0).a == 0.0, "The finish burst must have transparent corners")
	assert(VehicleVisualAnimation.overdrive_flame_length(0.0, 0.0, false) == 0.0, "Inactive overdrive must not draw ignition flames")
	assert(VehicleVisualAnimation.overdrive_flame_length(0.2, 1.0, false) >= 42.0, "Option A must use a visibly stronger flame than normal acceleration")
	assert(is_equal_approx(VehicleVisualAnimation.overdrive_glow_alpha(0.0, 0.75, true), VehicleVisualAnimation.overdrive_glow_alpha(1.0, 0.75, true)), "Reduced flashing must replace pulsing overdrive glow with a stable cue")
	assert(VehicleVisualAnimation.overdrive_afterimage_alpha(0, 1.0) > VehicleVisualAnimation.overdrive_afterimage_alpha(1, 1.0), "Option A must use two bounded afterimages that fade with distance")

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var constants: Dictionary = main.get_script().get_script_constant_map()
	assert(constants.has("FINISH_BURST_TEXTURE"), "Main must preload the generated finish burst")
	var finish_burst := main.get_node("CanvasLayer/ResultScreen/FinishBurst") as TextureRect
	var result_emblem := main.get_node("CanvasLayer/ResultScreen/Center/Card/Content/ResultEmblem") as TextureRect
	var overdrive_label := main.get_node("CanvasLayer/RaceHUD/Rows/OverdriveLabel") as Label
	var overdrive_gauge := main.get_node("CanvasLayer/RaceHUD/Rows/OverdriveGauge") as ProgressBar
	assert(finish_burst.texture != null, "The finish celebration node must use the generated effect texture")
	assert(overdrive_label != null and overdrive_gauge != null, "The selected overdrive direction must have a dedicated HUD status and meter")
	main.overdrive.observe_accelerate_press(100.0, 100.0)
	main.overdrive.tick(0.1, 100.0)
	main.overdrive.observe_accelerate_press(100.0, 100.0)
	main._update_hud()
	assert(overdrive_label.text.contains("超载") and overdrive_gauge.value > 0.99, "A newly activated overdrive must be explicit and start with a full-duration meter")

	main._start_new_run()
	main.run.phase = main.RunState.Phase.RUN_CLEAR
	main.feedback.start_finish()
	main._update_hud()
	assert(finish_burst.visible, "Run clear must show the finish burst")
	assert(result_emblem.scale.x < 1.0, "The result emblem must begin its entrance animation below full size")

	main.feedback.tick(3.0, main.run.fuel, main.run.difficulty_stage)
	main._update_hud()
	assert(not finish_burst.visible, "The finish burst must hide after its bounded timeline")
	assert(result_emblem.scale.is_equal_approx(Vector2.ONE), "The result emblem must settle at its authored size")
	main.queue_free()
	await process_frame
	quit()
