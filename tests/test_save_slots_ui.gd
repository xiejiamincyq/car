extends SceneTree
const Slots = preload("res://scripts/save_slots.gd")
const Store = preload("res://scripts/save_store.gd")
const Teardown = preload("res://tests/support/audio_teardown.gd")
var failures: Array[String] = []
var checks := 0
func _key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func _init() -> void:call_deferred("_run")
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_check(main.has_method("_configure_save_slots"),"Main must integrate the four-slot manager, not only its storage")
	if main.has_method("_configure_save_slots"):
		var directory := "res://tmp/save-slots-ui-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
		var manager := Slots.new(directory,directory+"/absent.cfg")
		main._configure_save_slots(manager)
		main._title_action("SaveButton").pressed.emit()
		await process_frame
		var ui = main.save_slots_screen
		_check(ui.visible and not main.title_screen.visible,"Title opens manager instead of starting a race")
		_check(ui.cards.size()==4,"Exactly four independently actionable cards")
		main.save_data.career.runs=18
		main.audio_director.music_volume=0.31
		ui.cards[0].save.pressed.emit()
		_check(manager.slot_info(1).data.career.runs==18,"Active save writes actual progress")
		ui.cards[1].load.pressed.emit()
		_check(manager.active_slot==2 and main.save_data.career.runs==0,"Loading empty slot establishes independent defaults")
		main.save_data.career.runs=7
		ui.cards[1].save.pressed.emit()
		ui.cards[0].delete.pressed.emit()
		await _key(KEY_TAB)
		_check(root.gui_get_focus_owner()==ui.confirm_button,"Tab traverses only visible delete modal actions")
		await _key(KEY_TAB)
		_check(root.gui_get_focus_owner()==ui.cancel_button,"Tab wraps inside modal, never to slot buttons")
		await _key(KEY_SPACE)
		_check(not ui.modal.visible and manager.slot_info(1).status==&"primary","Space on default cancel neither deletes nor starts a race")
		ui.cards[0].delete.pressed.emit()
		await _key(KEY_ESCAPE)
		_check(not ui.modal.visible and ui.visible,"Esc dismisses top confirmation, not underlying manager")
		_check(root.gui_get_focus_owner()==ui.cards[0].delete,"Cancelled confirmation restores initiating action")
		ui.cards[0].copy.pressed.emit()
		_check(ui.modal.visible and root.gui_get_focus_owner()==ui.cancel_button,"Copy is a modal with safe cancel focus")
		ui.target_picker.select(1)
		ui._refresh_copy_prompt()
		ui.cancel_button.pressed.emit()
		_check(manager.slot_info(2).data.career.runs==7,"Cancel copy performs zero profile writes")
		ui.cards[0].copy.pressed.emit()
		ui.target_picker.select(1)
		ui._refresh_copy_prompt()
		ui.confirm_button.pressed.emit()
		_check(manager.active_slot==2 and main.save_data.career.runs==18,"Overwrite of current slot reloads Main memory")
		_check(is_equal_approx(main.audio_director.music_volume,0.31),"Copied independent audio preferences are applied")
		main._save_preferences()
		_check(manager.slot_info(2).data.career.runs==18,"A later auto-save cannot undo an approved copy")
		ui.cards[1].delete.pressed.emit()
		_check(ui.modal.visible and root.gui_get_focus_owner()==ui.cancel_button,"Delete defaults to cancel")
		ui.cancel_button.pressed.emit()
		_check(manager.slot_info(2).status==&"primary","Cancelled delete retains primary")
		ui.cards[1].delete.pressed.emit()
		ui.confirm_button.pressed.emit()
		_check(manager.active_slot==0 and not main.persistence_enabled,"Deleting current slot disables persistence")
		_check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().is_visible_in_tree() and not root.gui_get_focus_owner().disabled,"Confirmed deletion retains an enabled keyboard focus target")
		_check(not main._save_preferences() and manager.slot_info(2).status==&"missing","No resurrection after current delete")
		_check(FileAccess.file_exists(manager.last_archive_path+"/save.cfg"),"Deleted slot is recoverable")
		ui.back_button.pressed.emit()
		_check(not ui.visible and main.title_screen.visible and root.gui_get_focus_owner()==main._title_action("SaveButton"),"Return restores title entry focus")
		main.run.phase=main.RunState.Phase.RUNNING
		main._show_save_slots()
		_check(not ui.visible,"Driving cannot open profile management")
		main.run.phase=main.RunState.Phase.TITLE
		ui.cards[0].load.pressed.emit()
		main.save_data.career.runs=19
		main._save_preferences()
		var damaged := ConfigFile.new()
		damaged.set_value("broken","fixture",true)
		damaged.save(directory+"/slot_1/save.cfg")
		main._configure_save_slots(manager)
		main._show_save_slots()
		_check(ui.cards[0].title.text.contains("备份恢复") or ui.cards[0].title.text.contains("RECOVERED"),"Current badge cannot hide recovered-backup status")
		damaged.save(directory+"/slot_1/save.cfg.bak")
		main._configure_save_slots(manager)
		main._refresh_save_slots()
		var bad_hash := FileAccess.get_sha256(directory+"/slot_1/save.cfg")
		_check(not main.persistence_enabled,"Unreadable active profile cannot write default progress")
		ui.cards[2].load.pressed.emit()
		_check(manager.active_slot==3 and main.persistence_enabled,"Damaged current profile cannot trap the user from loading a healthy or empty profile")
		_check(FileAccess.get_sha256(directory+"/slot_1/save.cfg")==bad_hash,"Switching away from damage preserves the unreadable original")
	var audio := Teardown.capture(main)
	main.audio_director.shutdown()
	main.queue_free()
	await process_frame
	_check(await Teardown.wait_for_release(self,audio),"Audio lifecycle retired before test exit")
	for failure in failures:push_error(failure)
	print("SLOT_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	print("TEST_COMPLETE test_save_slots_ui.gd")
	quit(0 if failures.is_empty() else 1)
