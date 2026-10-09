extends Control

const CYAN := Color("63e5f2")
const MUTED := Color("739ba9")
const GOLD := Color("ffda77")
const BACKGROUND := Color(0.02, 0.055, 0.085, 0.70)
const RouteMap = preload("res://scripts/ui/race_route_map.gd")
var route_map: Control
var speed_ratio := 0.0
var fuel_ratio := 1.0
var displayed_speed := 0.0
var language := "zh"
var integrity_gauge: ProgressBar
var _panel_style: StyleBoxFlat
var _initialized_speed := false
var _coin_count := 0
var _coin_pulse := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style = _box(BACKGROUND)
	$Rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Panel.visible = false
	$HUDFrame.visible = false
	$Rows/ControlsHint.visible = false
	$Rows/Fuel.visible = false
	$Rows/FuelGauge.visible = false
	integrity_gauge = ProgressBar.new()
	integrity_gauge.name = "IntegrityGauge"
	integrity_gauge.show_percentage = false
	integrity_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(integrity_gauge)
	route_map = RouteMap.new()
	route_map.name = "RouteMap"
	add_child(route_map)
	for bar in [$Rows/FuelGauge, $Rows/ProgressGauge, $Rows/OverdriveGauge, integrity_gauge]:
		bar.add_theme_stylebox_override("background", _box(Color("142633")))
		bar.add_theme_stylebox_override("fill", _box(Color.WHITE if bar in [integrity_gauge, $Rows/FuelGauge] else CYAN))
	$Rows/Fuel.add_theme_color_override("font_color", Color.WHITE)
	resized.connect(layout_instruments)
	layout_instruments()

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	return box

func _place(node: Control, rect: Rect2, font_size: int = 16, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	node.position = rect.position
	node.size = rect.size
	node.scale = Vector2.ONE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node is Label:
		node.add_theme_font_size_override("font_size", font_size)
		node.add_theme_constant_override("outline_size", 3)
		node.horizontal_alignment = alignment
		node.clip_text = true

func layout_instruments() -> void:
	var w := size.x
	var h := size.y
	_place(route_map, Rect2(0,192,224,minf(400.0,maxf(150.0,h-468.0))))
	_place($Rows/RunStatus, Rect2(12, 8, 370, 48), 16)
	$Rows/RunStatus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place($Rows/Score, Rect2(w-222, 25, 208, 40), 32, HORIZONTAL_ALIGNMENT_RIGHT)
	_place($CoinLabel, Rect2(w-222, 67, 208, 32), 22, HORIZONTAL_ALIGNMENT_RIGHT)
	_place($IntegrityLabel, Rect2(12, 80, 198, 26), 15)
	_place(integrity_gauge, Rect2(12, 112, 198, 12))
	_place($Rows/Fuel, Rect2(12, 130, 198, 26), 14)
	_place($Rows/FuelGauge, Rect2(12, 160, 198, 12))
	_place($Rows/OverdriveLabel, Rect2(12, 132, 198, 24), 14)
	_place($Rows/OverdriveGauge, Rect2(12, 160, 198, 6))
	_place($Rows/Position, Rect2(w*0.5-220, 9, 440, 24), 15, HORIZONTAL_ALIGNMENT_CENTER)
	$Rows/Position.visible = true
	_place($Rows/ProgressGauge, Rect2(w*0.5-220, 42, 440, 8))
	_place($Rows/Speed, Rect2(12, h-167, 198, 54), 44, HORIZONTAL_ALIGNMENT_CENTER)
	queue_redraw()

func present(speed: float, maximum_speed: float, fuel: float, hull: float, value_language: String, coins: int = 0) -> void:
	speed_ratio = clampf(speed/maxf(1.0, maximum_speed), 0.0, 1.0)
	fuel_ratio = clampf(fuel/100.0, 0.0, 1.0)
	language = value_language
	if coins > _coin_count: _coin_pulse = 0.24
	if coins < _coin_count: _coin_pulse = 0.0
	_coin_count = coins
	_coin_pulse = maxf(0.0, _coin_pulse-get_process_delta_time())
	$CoinLabel.modulate = Color.WHITE.lerp(Color("fff1bb"), _coin_pulse/0.24)
	integrity_gauge.value = hull
	integrity_gauge.modulate = Color("ff7676") if hull <= 30 else (GOLD if hull <= 70 else CYAN)
	displayed_speed = move_toward(displayed_speed, speed_ratio, get_process_delta_time()*2.8) if _initialized_speed else speed_ratio
	_initialized_speed = true
	queue_redraw()

func _panel(rect: Rect2) -> void:
	draw_style_box(_panel_style, rect)
	draw_line(rect.position+Vector2(0, 1), rect.position+Vector2(rect.size.x, 1), Color(CYAN, 0.45), 2, true)

func _dial(center: Vector2, radius: float, ratio: float, accent: Color, ticks: int) -> void:
	var start := deg_to_rad(140)
	var sweep := deg_to_rad(260)
	draw_arc(center, radius, start, start+sweep, 64, Color("1c3948"), 6, true)
	if ratio > 0:
		draw_arc(center, radius, start, start+sweep*ratio, 64, accent, 4, true)
	for tick in range(ticks+1):
		var direction := Vector2.from_angle(start+sweep*float(tick)/ticks)
		draw_line(center+direction*(radius-10), center+direction*(radius-4), MUTED if float(tick)/ticks > ratio else accent, 2, true)
	var needle := Vector2.from_angle(start+sweep*ratio)
	draw_line(center+needle*12, center+needle*(radius-17), Color(accent, 0.60), 2, true)
	draw_circle(center, 3, accent)

func _draw() -> void:
	_panel(Rect2(0, 0, 386, 64))
	_panel(Rect2(0, 74, 224, 106))
	_panel(Rect2(size.x-234, 0, 234, 110))
	_panel(Rect2(size.x*0.5-234, 0, 468, 62))
	_panel(Rect2(0, size.y-262, 224, 262))
	_dial(Vector2(111, size.y-155), 78, displayed_speed, CYAN, 16)
	var fuel_color := Color("ff7676") if fuel_ratio <= 0.15 else (GOLD if fuel_ratio <= 0.3 else Color("76edb6"))
	_dial(Vector2(52, size.y-47), 30, fuel_ratio, fuel_color, 8)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(size.x-222, 18), "得分 / SCORE" if language == "zh" else "SCORE", HORIZONTAL_ALIGNMENT_RIGHT, 208, 13, MUTED)
	draw_string(font, Vector2(89, size.y-102), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	draw_string(font, Vector2(16, size.y-238), "速度 / SPEED" if language == "zh" else "SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	draw_string(font, Vector2(100, size.y-46), "%d%%" % roundi(fuel_ratio*100), HORIZONTAL_ALIGNMENT_LEFT, -1, 23, fuel_color)
	draw_string(font, Vector2(100, size.y-23), "燃油 / FUEL" if language == "zh" else "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	for threshold in [0.3, 0.7]:
		var x: float = 12+198*threshold
		draw_line(Vector2(x, 110), Vector2(x, 126), GOLD, 1)
