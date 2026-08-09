extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

const EXPECTED_ASSETS := {
	"res://assets/vehicles/player_car.png": Vector2i(96, 112),
	"res://assets/vehicles/traffic_sedan.png": Vector2i(80, 112),
	"res://assets/vehicles/traffic_truck.png": Vector2i(96, 176),
	"res://assets/pickups/fuel_pickup.png": Vector2i(64, 64),
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for asset_path in EXPECTED_ASSETS:
		var texture := load(asset_path) as Texture2D
		assert(texture != null, "%s must import as a Texture2D" % asset_path)
		assert(texture.get_size() == Vector2(EXPECTED_ASSETS[asset_path]), "%s must keep its frozen gameplay canvas" % asset_path)
		var image := texture.get_image()
		assert(image.get_pixel(0, 0).a == 0.0, "%s must have a transparent top-left corner" % asset_path)
		assert(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a == 0.0, "%s must have a transparent bottom-right corner" % asset_path)

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var constants: Dictionary = main.get_script().get_script_constant_map()
	assert(constants.has("PLAYER_CAR_TEXTURE") and constants.has("TRAFFIC_SEDAN_TEXTURE") and constants.has("TRAFFIC_TRUCK_TEXTURE") and constants.has("FUEL_PICKUP_TEXTURE"), "Main must preload every gameplay art asset")
	assert(main.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Gameplay pixel art must use nearest-neighbor filtering")
	assert(main._traffic_texture_for_kind(TrafficDirector.Kind.STEADY_SLOW) == constants["TRAFFIC_SEDAN_TEXTURE"], "Normal traffic must use the sedan art")
	assert(main._traffic_texture_for_kind(TrafficDirector.Kind.TRUCK) == constants["TRAFFIC_TRUCK_TEXTURE"], "Truck traffic must use the long truck art")
	main.queue_free()
	await process_frame
	quit()
