extends SceneTree

const TourMapController = preload("res://scripts/ui/tour_map_controller.gd")
const TourProgress = preload("res://scripts/catalog/tour_progress.gd")
const TourMapScene = preload("res://scenes/tour_map.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var progress := TourProgress.default_data()
	var map := TourMapController.new(progress)
	assert(map.selected_track_id() == &"neon_coast", "The map must open on the saved starter track")
	assert(map.can_confirm(), "The starter track must be confirmable")
	map.move(1)
	assert(map.selected_track_id() == &"freight_harbor", "Map navigation must visit the next node even when locked")
	assert(not map.can_confirm(), "Locked map nodes must not be confirmable")
	map.move(10)
	assert(map.selected_track_id() == &"sunrise_express", "Map navigation must clamp at the final node")
	map.move(-10)
	assert(map.selected_track_id() == &"neon_coast", "Map navigation must clamp at the first node")
	progress = TourProgress.record_result(progress, &"neon_coast", 5400, 205.0, true, 1)
	map.set_progress(progress)
	map.move(1)
	assert(map.can_confirm() and map.confirm(), "A newly unlocked map node must become selectable")
	assert(progress.selected_track_id == &"freight_harbor", "Map confirmation must mutate the shared progress selection")
	assert(map.node_states().size() == 4 and map.node_states()[1].unlocked, "The map must expose four renderable node states")
	var screen := TourMapScene.instantiate()
	root.add_child(screen)
	await process_frame
	screen.setup(progress, "zh")
	screen.open()
	await process_frame
	assert(screen.visible and screen.track_buttons[1].has_focus(), "The tour screen must focus the saved track for keyboard play")
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.content_scale_size = size
		await process_frame
		assert(screen.get_global_rect().encloses(screen.get_node("Center/Card").get_global_rect()), "The tour card must fit inside the %s viewport" % size)
	assert(screen.heading.text == "霓虹海岸巡回赛" and screen.track_buttons.size() == 4, "The tour screen must render four localized nodes")
	root.content_scale_size = Vector2i(1280, 720)
	screen.queue_free()
	await process_frame
	quit()
