extends RefCounted
## Menu-only styling: no racing HUD, input, save data or audio changes.

const NAVY := Color("081727")
const CYAN := Color("66ddd4")
const GOLD := Color("edc77d")
const MENUS := ["TitleScreen", "LeaderboardScreen", "TourMapScreen", "VehicleSelectScreen", "SettingsScreen", "ControlsScreen", "PauseScreen", "ResultScreen", "ConfirmationScreen"]

static func apply(canvas_layer: Node) -> void:
	var shared := _theme()
	for name in MENUS:
		var screen: Control = canvas_layer.get_node(name)
		screen.theme = shared
		var content: VBoxContainer = screen.get_node("Center/Card/Content")
		content.add_theme_constant_override("separation", 10)
		for button in content.find_children("*", "Button", true, false):
			if button.name in ["StartButton", "ResumeButton", "ReplayButton"] or (name == "VehicleSelectScreen" and button.name == "ConfirmButton"):
				button.theme_type_variation = &"PrimaryButton"
			elif button.name in ["QuitButton", "ConfirmButton"]:
				button.theme_type_variation = &"DangerButton"
		for label in content.find_children("*", "Label", true, false):
			if label.name in ["Heading", "Title"]:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				label.add_theme_font_size_override("font_size", 30)
				label.add_theme_color_override("font_color", Color("e8f1f1"))
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
	garage.add_theme_constant_override("separation", 6)
	garage.get_node("Details").custom_minimum_size.y = 26
	garage.get_node("PreviewFrame").custom_minimum_size = Vector2(970, 170)
	garage.get_node("Hint").add_theme_font_size_override("font_size", 14)
	for button in garage.find_child("Vehicles", true, false).get_children():
		button.custom_minimum_size.y = 105
		button.add_theme_font_size_override("font_size", 17)
	_apply_title(canvas_layer)
	_apply_settings(canvas_layer)
	_apply_result(canvas_layer)
	var board: VBoxContainer = canvas_layer.get_node("LeaderboardScreen/Center/Card/Content")
	board.get_parent().custom_minimum_size.x = 760
	var grid := GridContainer.new()
	grid.name = "ScoreGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 18)
	board.add_child(grid)
	board.move_child(grid, 1)

static func _apply_settings(canvas_layer: Node) -> void:
	var content: VBoxContainer = canvas_layer.get_node("SettingsScreen/Center/Card/Content")
	content.get_parent().custom_minimum_size.x = 800
	content.add_theme_constant_override("separation", 8)
	var audio: VBoxContainer = content.get_node("AudioLevels")
	for row in audio.get_children():
		if row is HBoxContainer: row.custom_minimum_size.y = 36
	content.get_node("MuteButton").custom_minimum_size.y = 44
	for group in [["DisplayActions", "FullscreenButton", "LanguageButton"], ["AssistActions", "HighContrastButton", "ReducedFlashingButton", "ScreenShakeButton"]]:
		var label := Label.new()
		label.name = String(group[0])+"Heading"
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", CYAN)
		content.add_child(label)
		var grid := GridContainer.new()
		grid.name = group[0]
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 10)
		content.add_child(grid)
		for index in range(1, group.size()):
			var button: Button = content.get_node(group[index])
			button.reparent(grid)
			button.custom_minimum_size = Vector2(368, 48)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back: Button = content.get_node("BackButton")
	content.move_child(back, content.get_child_count()-1)
	back.custom_minimum_size.y = 50
	audio.refresh_focus_route()

static func _apply_result(canvas_layer: Node) -> void:
	var content: VBoxContainer = canvas_layer.get_node("ResultScreen/Center/Card/Content")
	content.get_parent().custom_minimum_size.x = 760
	content.add_theme_constant_override("separation", 10)
	content.get_node("ResultEmblem").hide()
	var rating = content.get_node("RatingCard")
	rating.headline.add_theme_font_size_override("font_size", 50)
	rating.best_label.add_theme_font_size_override("font_size", 17)
	for cell in rating.cells:
		cell.style.set_corner_radius_all(6)
		cell.title.add_theme_font_size_override("font_size", 18)
		cell.points.add_theme_font_size_override("font_size", 28)
		cell.detail.add_theme_font_size_override("font_size", 16)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	for action_name in ["TitleButton", "ReplayButton"]:
		var button: Button = content.get_node(action_name)
		button.reparent(actions)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(348, 50)

static func _apply_title(canvas_layer: Node) -> void:
	var screen: Control = canvas_layer.get_node("TitleScreen")
	var center: CenterContainer = screen.get_node("Center")
	var card: PanelContainer = center.get_node("Card")
	var content: VBoxContainer = card.get_node("Content")
	var title: Label = content.get_node("Title")
	center.anchor_right = 0.48
	card.custom_minimum_size.x = 440
	content.add_theme_constant_override("separation", 10)
	content.get_node("Logo").custom_minimum_size.y = 178
	content.get_node("Spacer").custom_minimum_size.y = 2
	var start: Button = content.get_node("StartButton")
	start.custom_minimum_size.y = 60
	start.add_theme_font_size_override("font_size", 23)
	content.get_node("DifficultyButton").custom_minimum_size.y = 40
	var grid := GridContainer.new()
	grid.name = "SecondaryActions"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for action_name in ["LeaderboardButton", "SaveButton", "SettingsButton", "ControlsButton"]:
		var button: Button = content.get_node(action_name)
		button.reparent(grid)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(188, 46)
	var quit: Button = content.get_node("QuitButton")
	content.move_child(quit, content.get_child_count()-1)
	quit.add_theme_color_override("font_color", Color("a7bcc7"))
	quit.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, Color("34525e"), 8, 9))
	var buttons: Array[Control] = []
	for action_name in ["StartButton", "DifficultyButton", "LeaderboardButton", "SaveButton", "SettingsButton", "ControlsButton", "QuitButton"]:
		buttons.append(content.find_child(action_name, true, false))
	for index in buttons.size():
		buttons[index].focus_next = buttons[index].get_path_to(buttons[(index+1)%buttons.size()])
		buttons[index].focus_previous = buttons[index].get_path_to(buttons[(index+buttons.size()-1)%buttons.size()])
	# Explicit grid neighbours are independent of the linear Tab route.
	var adjacent := [[0,0,6,1],[1,1,0,2],[2,3,1,4],[2,3,1,5],[4,5,2,6],[4,5,3,6],[6,6,4,0]]
	for index in buttons.size():
		for side in 4:
			buttons[index].set(["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom"][side], buttons[index].get_path_to(buttons[adjacent[index][side]]))
	title.text = "NEON COAST\nRUSH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_outline_color", Color("06121f"))
	title.add_theme_constant_override("outline_size", 3)
	var panel := _box(Color(0.025, 0.065, 0.11, 0.70), CYAN, 14, 28)
	panel.set_border_width_all(0)
	panel.border_width_top = 1
	card.add_theme_stylebox_override("panel", panel)
	# The scenic title is lighter; other menus keep their readable dark backdrop.
	var shade: ColorRect = canvas_layer.get_node("MenuBackdrop/MenuShade")
	var update_shade := func(): shade.color.a = 0.22 if screen.is_visible_in_tree() else 0.48
	screen.visibility_changed.connect(update_shade)
	update_shade.call()

static func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("e8f1f1"))
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
	focus.border_color = Color("e8f1f1")
	focus.set_border_width_all(2)
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
