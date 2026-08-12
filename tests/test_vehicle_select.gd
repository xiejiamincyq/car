extends SceneTree

const TourProgress = preload("res://scripts/catalog/tour_progress.gd")
const VehicleSelectController = preload("res://scripts/ui/vehicle_select_controller.gd")
const VehicleSelectScene = preload("res://scenes/vehicle_select.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var progress := TourProgress.default_data()
	var selector := VehicleSelectController.new(progress)
	assert(selector.selected_vehicle_id() == &"pulse_gt" and selector.can_confirm(), "The garage must open on the saved balanced car")
	selector.move(1)
	assert(selector.selected_vehicle_id() == &"driftwing" and selector.confirm(), "An unlocked starter vehicle must be selectable")
	assert(progress.selected_vehicle_id == &"driftwing", "Vehicle confirmation must update shared progress")
	selector.move(4)
	assert(selector.selected_vehicle_id() == &"aurora_x" and not selector.can_confirm(), "The garage must show locked cars without allowing selection")
	var state := selector.selected_state()
	assert(state.has("max_speed") and state.has("acceleration") and state.has("braking") and state.has("steering_speed") and state.has("collision_speed_penalty"), "The garage must expose all five vehicle attributes")
	assert(not state.unlocked and not String(state.unlock_key).is_empty(), "Locked vehicles must explain their unlock condition")
	var screen := VehicleSelectScene.instantiate()
	root.add_child(screen)
	await process_frame
	screen.setup(progress, "zh")
	screen.open()
	await process_frame
	assert(screen.visible and screen.vehicle_buttons[1].has_focus(), "The garage must focus the saved vehicle for keyboard play")
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.content_scale_size = size
		await process_frame
		assert(screen.get_global_rect().encloses(screen.get_node("Center/Card").get_global_rect()), "The garage card must fit inside the %s viewport" % size)
	assert(screen.heading.text == "选择赛车" and screen.vehicle_buttons.size() == 6, "The garage must render six localized vehicle choices")
	assert(screen.preview.texture != null and screen.preview.texture.resource_path.ends_with("player_driftwing.png"), "The garage must preview the focused vehicle sprite")
	root.content_scale_size = Vector2i(1280, 720)
	screen.queue_free()
	await process_frame
	quit()
