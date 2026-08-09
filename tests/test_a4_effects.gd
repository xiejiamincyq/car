extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const FinishBurstTexture = preload("res://assets/effects/finish_burst.png")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(FinishBurstTexture.get_size() == Vector2(320, 320), "The finish burst must keep its frozen runtime canvas")
	assert(FinishBurstTexture.get_image().get_pixel(0, 0).a == 0.0, "The finish burst must have transparent corners")

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var constants: Dictionary = main.get_script().get_script_constant_map()
	assert(constants.has("FINISH_BURST_TEXTURE"), "Main must preload the generated finish burst")
	var finish_burst := main.get_node("CanvasLayer/ResultScreen/FinishBurst") as TextureRect
	var result_emblem := main.get_node("CanvasLayer/ResultScreen/Center/Card/Content/ResultEmblem") as TextureRect
	assert(finish_burst.texture != null, "The finish celebration node must use the generated effect texture")

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
