extends SceneTree

const Garage = preload("res://scenes/vehicle_select.tscn")
const Tour = preload("res://scripts/catalog/tour_progress.gd")
var failures: Array[String] = []
var checks := 0
var confirms := 0
var backs := 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _key(code: Key, shift := false) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		event.shift_pressed = shift
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
		await process_frame

func _run() -> void:
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await process_frame
		for language in ["zh","en"]:
			var screen = Garage.instantiate()
			root.add_child(screen)
			await process_frame
			screen.setup(Tour.default_data(),language)
			screen.vehicle_confirmed.connect(func(_id): confirms += 1)
			screen.back_requested.connect(func(): backs += 1)
			screen.open()
			for index in 6:
				screen.vehicle_buttons[index].grab_focus()
				await process_frame
				var unlocked: bool = screen.controller.can_confirm()
				var expected: Button = screen.confirm_button if unlocked else screen.back_button
				var original_confirms := confirms
				await _key(KEY_TAB)
				_check(expected.has_focus(),"Tab from vehicle %d goes directly to its valid action (%s %d)" % [index,language,resolution.y])
				_check(screen.controller.selected_index == index,"Tab does not inspect a different/locked vehicle")
				_check(confirms == original_confirms,"navigation never confirms a vehicle")
				await _key(KEY_TAB,true)
				_check(screen.vehicle_buttons[index].has_focus(),"reverse Tab returns to the inspected vehicle")
				if not unlocked:
					await _key(KEY_ENTER)
					_check(confirms == original_confirms,"Enter on locked vehicle cannot start a race")
				await _key(KEY_TAB)
				if unlocked:
					await _key(KEY_TAB)
					_check(screen.back_button.has_focus(),"confirm Tab reaches Back")
				await _key(KEY_TAB)
				_check(screen.vehicle_buttons[index].has_focus(),"Back Tab returns to inspected vehicle")
			# Directional browsing remains separate from the Tab action loop.
			screen.vehicle_buttons[0].grab_focus()
			await _key(KEY_RIGHT)
			_check(screen.controller.selected_index == 1,"Right still browses adjacent vehicle")
			await _key(KEY_DOWN)
			_check(screen.controller.selected_index == 4,"Down still browses locked lower-row vehicle")
			await _key(KEY_TAB)
			_check(screen.back_button.has_focus(),"Tab after arrow browsing skips disabled confirmation")
			await _key(KEY_TAB,true)
			_check(screen.vehicle_buttons[4].has_focus(),"reverse Tab restores lower-row vehicle")
			# The separate confirmation remains the only start action.
			screen.vehicle_buttons[0].grab_focus()
			await process_frame
			var before := confirms
			await _key(KEY_ENTER)
			_check(confirms == before,"Enter on car card only inspects, never starts")
			await _key(KEY_TAB)
			await _key(KEY_ENTER)
			_check(confirms == before+1,"Enter on focused confirmation emits exactly one start")
			var full := Tour.default_data()
			for result in full.track_results.values():
				result.cleared = true
				result.medal = 3
			screen.setup(full,language)
			screen.vehicle_buttons[5].grab_focus()
			await _key(KEY_TAB)
			_check(screen.confirm_button.has_focus() and not screen.confirm_button.disabled,"newly unlocked vehicle updates its action route")
			await _key(KEY_TAB,true)
			_check(screen.vehicle_buttons[5].has_focus(),"newly unlocked confirmation returns to saved inspection")
			screen.free()
			await process_frame
	print("VEHICLE_KEYBOARD_FOCUS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"real engine key events, localized standalone garage, two resolutions; no player save or desktop input"}))
	print("TEST_COMPLETE test_vehicle_keyboard_focus.gd")
	quit(0 if failures.is_empty() else 1)
