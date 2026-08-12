class_name VehicleSelectScreen
extends Control

signal vehicle_confirmed(vehicle_id: StringName)
signal back_requested

const GameText = preload("res://scripts/game_text.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const VehicleSelectController = preload("res://scripts/ui/vehicle_select_controller.gd")

var controller: VehicleSelectController
var language := GameText.LANGUAGE_EN

@onready var heading: Label = $Center/Card/Content/Heading
@onready var vehicle_buttons: Array[Button] = [
	$Center/Card/Content/Vehicles/Vehicle0, $Center/Card/Content/Vehicles/Vehicle1,
	$Center/Card/Content/Vehicles/Vehicle2, $Center/Card/Content/Vehicles/Vehicle3,
	$Center/Card/Content/Vehicles/Vehicle4, $Center/Card/Content/Vehicles/Vehicle5,
]
@onready var details: Label = $Center/Card/Content/Details
@onready var hint: Label = $Center/Card/Content/Hint
@onready var back_button: Button = $Center/Card/Content/BackButton

func _ready() -> void:
	for index in vehicle_buttons.size():
		vehicle_buttons[index].pressed.connect(_confirm_index.bind(index))
		vehicle_buttons[index].focus_entered.connect(_select_index.bind(index))
	back_button.pressed.connect(_request_back)

func setup(progress: Dictionary, active_language: String) -> void:
	language = active_language
	if controller == null:
		controller = VehicleSelectController.new(progress)
	else:
		controller.set_progress(progress)
	_refresh()

func open() -> void:
	visible = true
	_refresh()
	vehicle_buttons[controller.selected_index].grab_focus()

func move_selection(direction: int) -> void:
	if controller == null:
		return
	controller.move(direction)
	_refresh()
	vehicle_buttons[controller.selected_index].grab_focus()

func confirm_selection() -> bool:
	if controller == null or not controller.confirm():
		_refresh()
		return false
	vehicle_confirmed.emit(controller.selected_vehicle_id())
	return true

func _select_index(index: int) -> void:
	if controller == null or index == controller.selected_index:
		return
	controller.selected_index = index
	_refresh()

func _confirm_index(index: int) -> void:
	if controller == null:
		return
	controller.selected_index = index
	confirm_selection()

func _request_back() -> void:
	back_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() and event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_back()

func _refresh() -> void:
	if not is_node_ready() or controller == null:
		return
	heading.text = _text("garage.heading")
	var selected_index := controller.selected_index
	var vehicles := VehicleCatalog.all()
	for index in vehicles.size():
		controller.selected_index = index
		var state := controller.selected_state()
		var lock_text := "" if state.unlocked else _text("garage.locked_short")
		vehicle_buttons[index].text = "%s\n%s\n%s" % [_text(String(state.name_key)), _text(String(state.role_key)), lock_text]
		vehicle_buttons[index].modulate = Color.WHITE if state.unlocked else Color(0.62, 0.68, 0.76)
	controller.selected_index = selected_index
	var selected := controller.selected_state()
	var availability := _text("garage.available") if selected.unlocked else _text(String(selected.unlock_key))
	details.text = _text("garage.details", [_text(String(selected.name_key)), _text(String(selected.role_key)), availability,
		roundi(selected.max_speed), roundi(selected.acceleration), roundi(selected.braking),
		roundi(selected.steering_speed), roundi(selected.collision_speed_penalty)])
	hint.text = _text("garage.hint")
	back_button.text = _text("settings.back")

func _text(key: String, values: Array = []) -> String:
	return GameText.get_text(key, language, values)
