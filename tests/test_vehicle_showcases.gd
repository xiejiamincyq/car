extends SceneTree
const Garage = preload("res://scenes/vehicle_select.tscn")
const Tour = preload("res://scripts/catalog/tour_progress.gd")
const Catalog = preload("res://scripts/catalog/vehicle_catalog.gd")
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _run() -> void:
	var progress := Tour.default_data()
	for record in progress.track_results.values(): record.cleared=true;record.medal=3
	var screen = Garage.instantiate()
	root.add_child(screen)
	screen.setup(progress,"zh")
	screen.open()
	for index in 6:
		screen._select_index(index)
		await process_frame
		var vehicle: Dictionary = Catalog.all()[index]
		var texture: Texture2D = screen.preview.texture
		_check(texture != null and texture.resource_path == "res://assets/vehicle_showcases/%s_northwest_v1.png" % vehicle.id,"Large preview uses this car's separate reference-generated showcase")
		_check(is_zero_approx(screen.preview.rotation) and screen.preview.scale.is_equal_approx(Vector2.ONE),"Showcase is not rotated or compressed by gameplay sprite calibration")
		_check(screen.preview.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Large preview scales proportionally")
		var thumbnail: TextureRect = screen.vehicle_buttons[index].get_node("Thumbnail")
		_check(thumbnail.texture.resource_path == vehicle.texture_path,"Right-side thumbnail retains its exact existing racing sprite")
		_check(screen.vehicle_buttons[index].custom_minimum_size.is_equal_approx(Vector2(230,105)),"Right six card sizes remain unchanged")
		_check(FileAccess.file_exists("res://art/source/vehicles/%s_chroma.png" % vehicle.id),"Original design source remains in place")
	screen.queue_free()
	await process_frame
	print("SHOWCASE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	print("TEST_COMPLETE test_vehicle_showcases.gd")
	quit(0 if failures.is_empty() else 1)
