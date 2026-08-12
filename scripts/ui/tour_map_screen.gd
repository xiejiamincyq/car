class_name TourMapScreen
extends Control

signal track_confirmed(track_id: StringName)
signal back_requested

const GameText = preload("res://scripts/game_text.gd")
const TourMapController = preload("res://scripts/ui/tour_map_controller.gd")

var controller: TourMapController
var language := GameText.LANGUAGE_EN

@onready var heading: Label = $Center/Card/Content/Heading
@onready var track_buttons: Array[Button] = [
	$Center/Card/Content/Route/Track0, $Center/Card/Content/Route/Track1,
	$Center/Card/Content/Route/Track2, $Center/Card/Content/Route/Track3,
]
@onready var details: Label = $Center/Card/Content/Details
@onready var hint: Label = $Center/Card/Content/Hint
@onready var back_button: Button = $Center/Card/Content/BackButton

func _ready() -> void:
	for index in track_buttons.size():
		track_buttons[index].pressed.connect(_confirm_index.bind(index))
		track_buttons[index].focus_entered.connect(_select_index.bind(index))
	back_button.pressed.connect(_request_back)

func setup(progress: Dictionary, active_language: String) -> void:
	language = active_language
	if controller == null:
		controller = TourMapController.new(progress)
	else:
		controller.set_progress(progress)
	_refresh()

func open() -> void:
	visible = true
	_refresh()
	track_buttons[controller.selected_index].grab_focus()

func move_selection(direction: int) -> void:
	if controller == null:
		return
	controller.move(direction)
	_refresh()
	track_buttons[controller.selected_index].grab_focus()

func confirm_selection() -> bool:
	if controller == null or not controller.confirm():
		_refresh()
		return false
	track_confirmed.emit(controller.selected_track_id())
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
	heading.text = _text("tour.heading")
	var states := controller.node_states()
	for index in states.size():
		var state: Dictionary = states[index]
		var lock_text := "" if state.unlocked else _text("tour.locked_short")
		track_buttons[index].text = "%02d  %s\n%s" % [index + 1, _text(String(state.name_key)), lock_text]
		track_buttons[index].modulate = Color.WHITE if state.unlocked else Color(0.62, 0.68, 0.76)
	var selected: Dictionary = states[controller.selected_index]
	var result: Dictionary = selected.result
	var status := _text("tour.available") if selected.unlocked else _text("tour.locked")
	details.text = _text("tour.details", [_text(String(selected.name_key)), status,
		_text("tour.medals.%d" % int(result.get("medal", 0))), int(result.get("best_score", 0)),
		_format_time(float(result.get("best_time", 0.0)))])
	hint.text = _text("tour.hint")
	back_button.text = _text("settings.back")

func _text(key: String, values: Array = []) -> String:
	return GameText.get_text(key, language, values)

func _format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--"
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]
