class_name VehicleSelectScreen
extends Control

signal vehicle_confirmed(vehicle_id: StringName)
signal back_requested

const GameText = preload("res://scripts/game_text.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const PlayerVehicleProfile = preload("res://scripts/player_vehicle_profile.gd")
const VehicleSelectController = preload("res://scripts/ui/vehicle_select_controller.gd")
const PerformanceChart = preload("res://scripts/ui/vehicle_performance_chart.gd")
const Showcases = preload("res://scripts/catalog/vehicle_showcase_catalog.gd")

var controller: VehicleSelectController
var language := GameText.LANGUAGE_EN
var performance_chart: Control

@onready var heading: Label = $Center/Card/Content/Heading
@onready var vehicle_buttons: Array[Button] = [
	$Center/Card/Content/Vehicles/Vehicle0, $Center/Card/Content/Vehicles/Vehicle1,
	$Center/Card/Content/Vehicles/Vehicle2, $Center/Card/Content/Vehicles/Vehicle3,
	$Center/Card/Content/Vehicles/Vehicle4, $Center/Card/Content/Vehicles/Vehicle5,
]
@onready var details: Label = $Center/Card/Content/Details
@onready var preview: TextureRect = $Center/Card/Content/PreviewFrame/Preview
@onready var hint: Label = $Center/Card/Content/Hint
@onready var back_button: Button = $Center/Card/Content/BackButton
@onready var confirm_button: Button = $Center/Card/Content/ConfirmButton

func _ready() -> void:
	performance_chart = PerformanceChart.new()
	performance_chart.position = Vector2(180, 0)
	performance_chart.size = Vector2(720, 180)
	performance_chart.scale = Vector2(0.88, 0.88)
	$Center/Card/Content/PreviewFrame.add_child(performance_chart)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.position = Vector2(44, 34)
	preview.size = Vector2(80, 112)
	preview.resized.connect(func(): preview.pivot_offset = preview.size * 0.5)
	for index in vehicle_buttons.size():
		vehicle_buttons[index].pressed.connect(_select_index.bind(index))
		vehicle_buttons[index].focus_entered.connect(_select_index.bind(index))
	back_button.pressed.connect(_request_back)
	confirm_button.pressed.connect(confirm_selection)
	$Center/Card/Content.move_child(confirm_button, back_button.get_index())
	_build_layout()

func _build_layout() -> void:
	var content: VBoxContainer = $Center/Card/Content
	content.add_theme_constant_override("separation", 10)
	hint.hide()
	var row := HBoxContainer.new()
	row.name = "VehicleGallery"
	row.add_theme_constant_override("separation", 20)
	row.custom_minimum_size.y = 230
	content.add_child(row)
	content.move_child(row, 1)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(240, 230)
	row.add_child(portrait)
	var stage := Control.new()
	portrait.add_child(stage)
	preview.reparent(stage)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var grid: GridContainer = content.get_node("Vehicles")
	grid.reparent(row)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_FILL
	for index in vehicle_buttons.size():
		var button := vehicle_buttons[index]
		button.custom_minimum_size = Vector2(230, 105)
		button.add_theme_font_size_override("font_size", 17)
		var thumbnail := TextureRect.new()
		thumbnail.name = "Thumbnail"
		thumbnail.texture = load(VehicleCatalog.all()[index].texture_path)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.position = Vector2(8, 20)
		thumbnail.size = Vector2(40, 65)
		thumbnail.pivot_offset = thumbnail.size * 0.5
		thumbnail.rotation = PlayerVehicleProfile.texture_rotation(VehicleCatalog.all()[index])
		thumbnail.scale = PlayerVehicleProfile.VISUAL_PROPORTION_SCALE
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(thumbnail)
	details.custom_minimum_size.y = 30
	details.add_theme_font_size_override("font_size", 21)
	content.get_node("PreviewFrame").custom_minimum_size = Vector2(970, 170)
	performance_chart.position = Vector2(150, 0)
	performance_chart.scale = Vector2.ONE
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	back_button.reparent(actions)
	back_button.custom_minimum_size = Vector2(240, 52)
	confirm_button.reparent(actions)
	confirm_button.custom_minimum_size.y = 52
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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
		var selection_text := ("已选" if language == "zh" else "SELECTED") if index == selected_index else ""
		vehicle_buttons[index].text = "%s\n%s\n%s" % [_text(String(state.name_key)), _text(String(state.role_key)), lock_text if not lock_text.is_empty() else selection_text]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("193746") if index == selected_index else Color("102638")
		style.border_color = Color("edc77d") if index == selected_index else Color("34525e")
		style.set_border_width_all(2 if index == selected_index else 1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 48
		style.content_margin_right = 6
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		for state_name in ["normal", "hover", "pressed"]:
			vehicle_buttons[index].add_theme_stylebox_override(state_name, style)
		# A locked selected card still explicitly says it is the inspected choice.
		if not lock_text.is_empty() and not selection_text.is_empty():
			vehicle_buttons[index].text += " · " + selection_text
		vehicle_buttons[index].modulate = Color.WHITE if state.unlocked else Color(0.62, 0.68, 0.76)
	controller.selected_index = selected_index
	var selected := controller.selected_state()
	performance_chart.present(selected, language)
	confirm_button.disabled = not selected.unlocked
	confirm_button.text = _text("garage.confirm") if selected.unlocked else _text("garage.locked_short")
	_update_focus_route(selected.unlocked)
	preview.texture = Showcases.texture_for(StringName(selected.id))
	preview.pivot_offset = preview.size * 0.5
	preview.rotation = 0.0
	preview.scale = Vector2.ONE
	var availability := _text("garage.available") if selected.unlocked else _text(String(selected.unlock_key))
	details.text = "%s  ·  %s  ·  %s" % [_text(String(selected.name_key)), _text(String(selected.role_key)), availability]
	hint.text = _text("garage.hint")
	back_button.text = _text("settings.back")

func _update_focus_route(unlocked: bool) -> void:
	# Tab is the action shortcut; arrows remain the vehicle browsing controls.
	# Never traverse another card (which changes selection via focus_entered).
	var selected_button := vehicle_buttons[controller.selected_index]
	var action_button := confirm_button if unlocked else back_button
	for button in vehicle_buttons:
		button.focus_next = button.get_path_to(action_button)
		button.focus_previous = button.get_path_to(back_button)
	for index in range(3, 6):
		vehicle_buttons[index].focus_neighbor_bottom = vehicle_buttons[index].get_path_to(action_button)
	confirm_button.focus_previous = confirm_button.get_path_to(selected_button)
	confirm_button.focus_next = confirm_button.get_path_to(back_button)
	confirm_button.focus_neighbor_top = confirm_button.get_path_to(selected_button)
	back_button.focus_previous = back_button.get_path_to(confirm_button if unlocked else selected_button)
	back_button.focus_next = back_button.get_path_to(selected_button)
	back_button.focus_neighbor_top = back_button.focus_previous

func _text(key: String, values: Array = []) -> String:
	return GameText.get_text(key, language, values)
