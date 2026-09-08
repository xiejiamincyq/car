extends VBoxContainer

const GameText = preload("res://scripts/game_text.gd")
var headline: Label
var best_label: Label
var cells: Array[Dictionary] = []

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	headline = _label(38)
	add_child(headline)
	best_label = _label(16)
	add_child(best_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	for key in ["time", "overtakes", "collisions", "coins"]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("162c3e")
		style.border_color = Color("35536a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		grid.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var title := _label(16)
		var points := _label(26)
		var detail := _label(14)
		for label in [title, points, detail]: box.add_child(label)
		cells.append({"key": key, "title": title, "points": points, "detail": detail, "style": style})

func populate(rating: Dictionary, best: Dictionary, metrics: Dictionary, targets: Dictionary, language: String, high_contrast: bool) -> void:
	var rated := not rating.is_empty()
	headline.text = "%s   %d / 100" % [rating.grade, rating.total] if rated else GameText.get_text("rating.unrated", language)
	headline.add_theme_color_override("font_color", Color("ffd071") if rated else Color.WHITE)
	best_label.text = GameText.get_text("rating.best", language, [best.get("grade", "—"), best.get("total", "—")])
	var values := ["%.1f s" % metrics.time, str(metrics.overtakes), str(metrics.collisions), str(metrics.coins)]
	var goals := ["%.0f s" % float(targets.time), str(targets.overtakes), "0", str(targets.coins)]
	for index in range(cells.size()):
		var cell := cells[index]
		cell.title.text = GameText.get_text("rating." + cell.key, language)
		cell.points.text = "%d / %d" % [rating.parts[cell.key], 40 if index == 0 else 20] if rated else values[index]
		cell.points.add_theme_color_override("font_color", Color.WHITE if high_contrast else Color("50dcf1"))
		cell.detail.text = GameText.get_text("rating.detail", language, [values[index], goals[index]]) if rated else GameText.get_text("rating.no_points", language)
		cell.style.bg_color = Color("07111e") if high_contrast else Color("162c3e")
		cell.style.border_color = Color.WHITE if high_contrast else Color("35536a")

func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e6f4fa"))
	return label
