extends RefCounted
## Proposed presentation applied only to in-memory preview instances.
const Badge = preload("res://docs/previews/ui-review-20261012/badge.gd")
const VehicleCatalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const NAVY := Color("081727")
const CYAN := Color("66ddd4")
const GOLD := Color("edc77d")
const WHITE := Color("e8f1f1")
static func box(fill: Color, border: Color, padding := 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = padding; style.content_margin_right = padding
	style.content_margin_top = padding; style.content_margin_bottom = padding
	return style
static func label(text: String, font_size := 18) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",WHITE)
	return node
static func _button(button: Button, primary := false) -> void:
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_color_override("font_color",NAVY if primary else WHITE)
	button.add_theme_color_override("font_focus_color",NAVY if primary else WHITE)
	button.add_theme_color_override("font_hover_color",NAVY if primary else WHITE)
	button.add_theme_stylebox_override("normal",box(GOLD if primary else Color("102638"),GOLD if primary else Color("34525e"),10))
	button.add_theme_stylebox_override("hover",box(Color("f5dcaa") if primary else Color("173a47"),CYAN,10))
	button.add_theme_stylebox_override("pressed",box(GOLD.darkened(0.12) if primary else Color("0a1a2a"),GOLD,10))
	var focus := box(Color.TRANSPARENT,GOLD,0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
static func apply(main, state: String) -> void:
	var canvas: Node = main.get_node("CanvasLayer")
	for name in ["TitleScreen","TourMapScreen","VehicleSelectScreen","SettingsScreen","ControlsScreen","PauseScreen","ConfirmationScreen","LeaderboardScreen","ResultScreen"]:
		var card: PanelContainer = canvas.get_node(name+"/Center/Card")
		card.add_theme_stylebox_override("panel",box(Color(0.028,0.075,0.12,0.95),Color("35616a"),24))
		var content: VBoxContainer = card.get_node("Content")
		content.add_theme_constant_override("separation",12)
		for button in content.find_children("*","Button",true,false):
			_button(button,button.name in ["StartButton","ResumeButton","ReplayButton"] or (name == "VehicleSelectScreen" and button.name == "ConfirmButton"))
		for heading_name in ["Heading","Title"]:
			var heading := content.get_node_or_null(heading_name)
			if heading is Label:
				heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				heading.add_theme_font_size_override("font_size",30)
				heading.add_theme_color_override("font_color",WHITE)
	match state:
		"title": _title(main)
		"garage": _garage(main)
		"settings": _settings(main)
		"tour": _tour(main)
		"clear", "failed": _result(main)
		"board": _board(main)
static func _title(main) -> void:
	var center: CenterContainer = main.title_screen.get_node("Center")
	center.anchor_right = 0.48
	var card: PanelContainer = center.get_node("Card")
	card.custom_minimum_size = Vector2(440,0)
	card.add_theme_stylebox_override("panel",box(Color(0.025,0.065,0.105,0.70),Color(0.18,0.42,0.45,0.65),26))
	var content: VBoxContainer = card.get_node("Content")
	content.get_node("Logo").hide()
	var badge := Badge.new()
	badge.custom_minimum_size = Vector2(0,178)
	content.add_child(badge); content.move_child(badge,0)
	content.get_node("Spacer").custom_minimum_size.y = 2
	main.start_button.custom_minimum_size.y = 60
	main.start_button.add_theme_font_size_override("font_size",23)
	main.difficulty_button.custom_minimum_size.y = 40
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	content.add_child(grid)
	for name in ["LeaderboardButton","SaveButton","SettingsButton","ControlsButton"]:
		var button: Button = content.get_node(name)
		button.reparent(grid)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(188,46)
	var quit: Button = content.get_node("QuitButton")
	content.move_child(quit,content.get_child_count()-1)
	quit.add_theme_color_override("font_color",Color("a7bcc7"))
	quit.add_theme_stylebox_override("normal",box(Color(0,0,0,0),Color("34525e"),9))
static func _garage(main) -> void:
	var screen = main.vehicle_select_screen
	var card: PanelContainer = screen.get_node("Center/Card")
	card.custom_minimum_size = Vector2(1040,620)
	var content: VBoxContainer = card.get_node("Content")
	content.add_theme_constant_override("separation",10)
	content.get_node("Hint").hide()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	row.custom_minimum_size.y = 230
	content.add_child(row); content.move_child(row,1)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(240,230)
	portrait.add_theme_stylebox_override("panel",box(Color("0d2334"),Color("42636b"),8))
	row.add_child(portrait)
	var stage := Control.new()
	portrait.add_child(stage)
	screen.preview.reparent(stage)
	screen.preview.position = Vector2(71,18)
	screen.preview.size = Vector2(98,154)
	var selected := label("已选车型" if main.language == "zh" else "SELECTED",16)
	selected.position = Vector2(10,190); selected.size = Vector2(204,26)
	selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected.add_theme_color_override("font_color",GOLD)
	stage.add_child(selected)
	var grid: GridContainer = content.get_node("Vehicles")
	grid.reparent(row)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in screen.vehicle_buttons.size():
		var button: Button = screen.vehicle_buttons[index]
		button.custom_minimum_size = Vector2(230,105)
		button.add_theme_font_size_override("font_size",18)
		if index == screen.controller.selected_index:
			var active := box(Color("193746"),GOLD,10)
			active.set_border_width_all(2)
			button.add_theme_stylebox_override("normal",active)
		var thumbnail := TextureRect.new()
		thumbnail.texture = load(VehicleCatalog.all()[index].texture_path)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.position = Vector2(10,21); thumbnail.size = Vector2(40,65)
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(thumbnail)
	content.get_node("Details").add_theme_font_size_override("font_size",21)
	var chart: Control = content.get_node("PreviewFrame")
	chart.custom_minimum_size = Vector2(970,164)
	screen.performance_chart.position = Vector2(150,0)
	screen.performance_chart.scale = Vector2.ONE
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	content.add_child(actions)
	screen.back_button.reparent(actions)
	screen.back_button.custom_minimum_size.x = 240
	screen.confirm_button.reparent(actions)
	screen.confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.confirm_button.custom_minimum_size.y = 52
	screen.confirm_button.grab_focus()
static func _settings(main) -> void:
	var card: PanelContainer = main.settings_screen.get_node("Center/Card")
	card.custom_minimum_size.x = 800
	var content: VBoxContainer = card.get_node("Content")
	content.add_theme_constant_override("separation",14)
	content.get_node("AudioLevels/Hint").hide()
	var audio: VBoxContainer = content.get_node("AudioLevels")
	for row in audio.get_children():
		if row is HBoxContainer:
			row.custom_minimum_size.y = 42
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",12)
	content.add_child(grid)
	for name in ["MuteButton","FullscreenButton","LanguageButton","HighContrastButton","ReducedFlashingButton","ScreenShakeButton"]:
		var button: Button = content.get_node(name)
		button.reparent(grid)
		button.custom_minimum_size = Vector2(368,56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back: Button = content.get_node("BackButton")
	content.move_child(back,content.get_child_count()-1)
	back.custom_minimum_size.y = 50
static func _tour(main) -> void:
	var content: VBoxContainer = main.tour_map_screen.get_node("Center/Card/Content")
	for index in main.tour_map_screen.track_buttons.size():
		var button: Button = main.tour_map_screen.track_buttons[index]
		button.custom_minimum_size.y = 215
		var tile := TextureRect.new()
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var atlas := AtlasTexture.new()
		atlas.atlas = load(main.TrackCatalog.all()[index].environment_left_sequence_paths[0])
		var source_width := float(atlas.atlas.get_width())
		atlas.region = Rect2(0,0,source_width,source_width*92.0/214.0)
		tile.texture = atlas
		tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.position = Vector2(10,10); tile.size = Vector2(214,92)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.clip_contents = true
		tile.modulate.a = 0.85 if index == 0 else 0.40
		button.add_child(tile)
		button.clip_contents = true
		button.add_theme_constant_override("outline_size",0)
		var style := box(Color("122b3c"),GOLD if index == 0 else Color("33515c"),12)
		style.content_margin_top = 112
		button.add_theme_stylebox_override("normal",style)
	content.get_node("Hint").hide()
static func _result(main) -> void:
	var card: PanelContainer = main.result_screen.get_node("Center/Card")
	card.custom_minimum_size.x = 760
	var content: VBoxContainer = card.get_node("Content")
	content.add_theme_constant_override("separation",10)
	var emblem: TextureRect = content.get_node("ResultEmblem")
	emblem.hide()
	var rating: VBoxContainer = content.get_node("RatingCard")
	rating.headline.add_theme_font_size_override("font_size",50)
	rating.best_label.add_theme_font_size_override("font_size",17)
	for cell in rating.cells:
		cell.style.bg_color = Color("10293a")
		cell.style.border_color = Color("396069")
		cell.style.set_corner_radius_all(6)
		cell.title.add_theme_font_size_override("font_size",18)
		cell.points.add_theme_font_size_override("font_size",28)
		cell.detail.add_theme_font_size_override("font_size",16)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	content.add_child(actions)
	for name in ["TitleButton","ReplayButton"]:
		var button: Button = content.get_node(name)
		button.reparent(actions)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(348,50)
static func _board(main) -> void:
	var card: PanelContainer = main.leaderboard_screen.get_node("Center/Card")
	card.custom_minimum_size.x = 760
	var content: VBoxContainer = card.get_node("Content")
	content.get_node("BestScores").hide()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",28)
	grid.add_theme_constant_override("v_separation",18)
	content.add_child(grid); content.move_child(grid,1)
	for title in (["排名","得分","难度","距离"] if main.language == "zh" else ["RANK","SCORE","MODE","DISTANCE"]):
		var header := label(title,16)
		header.custom_minimum_size.x = 150
		header.add_theme_color_override("font_color",CYAN)
		grid.add_child(header)
	for index in main.save_data.top_scores.size():
		var entry: Dictionary = main.save_data.top_scores[index]
		for value in ["%02d" % (index+1),"%s" % entry.score,main._difficulty_name(entry.difficulty),"%d m" % entry.distance]:
			var item := label(value,22)
			item.add_theme_color_override("font_color",GOLD if index == 0 else WHITE)
			grid.add_child(item)
