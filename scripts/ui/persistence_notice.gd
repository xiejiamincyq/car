extends Label
## One non-modal status label, reused across menus and races without input capture.
var wide_menu := false

func _ready() -> void:
	name = "PersistenceNotice"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color("ffe3a4"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("10202bef")
	panel.border_color = Color("a47f47")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	add_theme_stylebox_override("normal", panel)
	get_viewport().size_changed.connect(_layout_notice)
	_layout_notice()
	hide()

func _layout_notice() -> void:
	var viewport_size := get_viewport_rect().size
	if wide_menu:
		var banner_width := minf(620.0, viewport_size.x - 32.0)
		position = Vector2((viewport_size.x - banner_width) * 0.5, 8.0)
		size = Vector2(banner_width, 36.0)
		return
	# Keep the center-bottom result/menu actions unobstructed. The side margin
	# is outside the playable lanes at the supported 1280x720 logical canvas.
	var width := minf(272.0, viewport_size.x - 32.0)
	position = Vector2(viewport_size.x - width - 16.0, viewport_size.y - 88.0)
	size = Vector2(width, 72.0)

func set_wide_menu(active: bool) -> void:
	if wide_menu != active:
		wide_menu = active
		_layout_notice()
