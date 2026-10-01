extends SceneTree
const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	main.set_process(false)
	main._open_tour_map()
	main._open_vehicle_select()
	var garage = main.vehicle_select_screen
	garage.vehicle_buttons[1].pressed.emit()
	assert(garage.visible and main.run.phase == main.RunState.Phase.TITLE, "Selecting a car must only inspect it, never start a race")
	assert(garage.controller.selected_vehicle_id() == &"driftwing")
	assert(garage.details.text.contains("漂移之翼"))
	assert(garage.performance_chart.values.size() == 5)
	garage.vehicle_buttons[5].pressed.emit()
	assert(garage.confirm_button.disabled, "Locked cars remain inspectable but cannot be confirmed")
	garage.vehicle_buttons[1].pressed.emit()
	assert(not garage.confirm_button.disabled)
	garage.confirm_button.pressed.emit()
	assert(main.run.phase == main.RunState.Phase.COUNTDOWN)
	assert(main.current_vehicle.id == &"driftwing")
	assert(not main.race_hud.get_node("Rows/Fuel").visible and not main.race_hud.get_node("Rows/FuelGauge").visible, "Fuel must only appear in the lower-left instruments")
	main.free()
	quit()
