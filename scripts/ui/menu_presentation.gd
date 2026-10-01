extends RefCounted
## Menu-only styling: no racing HUD, input, save data or audio changes.

const NAVY := Color("0b192c")
const CYAN := Color("49e6df")
const GOLD := Color("ffd16b")
const MENUS := ["TitleScreen", "TourMapScreen", "VehicleSelectScreen", "SettingsScreen", "ControlsScreen", "PauseScreen", "ResultScreen", "ConfirmationScreen"]

static func apply(canvas_layer: Node) -> void:
	var shared := _theme()
	for name in MENUS:
		var screen: Control = canvas_layer.get_node(name)
		screen.theme = shared
		var content: VBoxContainer = screen.get_node("Center/Card/Content")
		content.add_theme_constant_override("separation", 10)
		for button in content.find_children("*", "Button", true, false):
			if button.name in ["StartButton", "ResumeButton", "ReplayButton"]:
				button.theme_type_variation = &"PrimaryButton"
			elif button.name in ["QuitButton", "ConfirmButton"]:
				button.theme_type_variation = &"DangerButton"
		for label in content.find_children("*", "Label", true, false):
			if label.name in ["Heading", "Title"]:
				label.add_theme_color_override("font_color", CYAN)
			elif label.name in ["Hint", "Version"]:
				label.add_theme_color_override("font_color", Color("a8bdcc"))
	# Settings and results contain more rows; keep their actions accessible at 720p.
	var settings: VBoxContainer = canvas_layer.get_node("SettingsScreen/Center/Card/Content")
	settings.add_theme_constant_override("separation", 8)
	for button in settings.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = 38
	var results: VBoxContainer = canvas_layer.get_node("ResultScreen/Center/Card/Content")
	results.add_theme_constant_override("separation", 6)
	var result_panel := _box(NAVY, Color("29465c"), 14, 20)
	result_panel.border_width_top = 3
	result_panel.border_color = CYAN
	canvas_layer.get_node("ResultScreen/Center/Card").add_theme_stylebox_override("panel", result_panel)
	# Garage has a live vehicle preview in addition to six cards.
	var garage: VBoxContainer = canvas_layer.get_node("VehicleSelectScreen/Center/Card/Content")
	garage.add_theme_constant_override("separation", 8)
	garage.get_node("Details").custom_minimum_size.y = 94
	garage.get_node("PreviewFrame").custom_minimum_size.y = 86

static func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("e5f1f7"))
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.4))
	theme.set_constant("shadow_offset_y", "Label", 1)
	var panel := _box(NAVY, Color("29465c"), 16, 24)
	panel.border_width_top = 3
	panel.border_color = CYAN
	panel.shadow_color = Color(0.0, 0.02, 0.05, 0.55)
	panel.shadow_size = 12
	panel.shadow_offset = Vector2(0, 6)
	theme.set_stylebox("panel", "PanelContainer", panel)
	_button_styles(theme, "Button", Color("142c42"), Color("2d536b"), Color("e5f1f7"))
	theme.set_type_variation("PrimaryButton", "Button")
	_button_styles(theme, "PrimaryButton", GOLD, Color("ffe9ae"), NAVY)
	theme.set_type_variation("DangerButton", "Button")
	_button_styles(theme, "DangerButton", Color("302335"), Color("9c6472"), Color("ffc2b8"))
	return theme

static func _button_styles(theme: Theme, type: String, fill: Color, border: Color, text: Color) -> void:
	theme.set_stylebox("normal", type, _box(fill, border, 8, 8))
	theme.set_stylebox("hover", type, _box(fill.lightened(0.12), CYAN, 8, 8))
	theme.set_stylebox("pressed", type, _box(fill.darkened(0.14), GOLD, 8, 8))
	theme.set_stylebox("disabled", type, _box(Color("101d2c"), Color("263747"), 8, 8))
	var focus := _box(Color.TRANSPARENT, GOLD, 8, 0)
	focus.set_border_width_all(3)
	focus.expand_margin_left = 3
	focus.expand_margin_top = 3
	focus.expand_margin_right = 3
	focus.expand_margin_bottom = 3
	theme.set_stylebox("focus", type, focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, Color("788b9c"))

static func _box(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
