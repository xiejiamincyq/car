extends Control

const Catalog = preload("res://scripts/catalog/vehicle_catalog.gd")
const Config = preload("res://scripts/game_config.gd")
const KEYS := ["max_speed", "acceleration", "braking", "steering_speed", "collision_speed_penalty"]
var values: Array[float] = []
var actual: Array[float] = []
var language := "zh"

func present(vehicle: Dictionary, active_language: String) -> void:
	language = active_language
	values.clear()
	actual.clear()
	for key in KEYS:
		var maximum := 0.0
		for entry in Catalog.all():
			maximum = maxf(maximum, 1.0/entry[key] if key == "collision_speed_penalty" else entry[key])
		var value: float = 1.0/vehicle[key] if key == "collision_speed_penalty" else vehicle[key]
		values.append(value/maximum)
		actual.append(vehicle[key])
	queue_redraw()

func _draw() -> void:
	if values.size() != 5: return
	var cyan := Color("49e6df")
	var center := Vector2(92, 89)
	var labels := ["极速", "加速", "制动", "转向", "防护"] if language == "zh" else ["SPEED", "ACCEL", "BRAKE", "STEER", "PROTECT"]
	var directions: Array[Vector2] = []
	for i in range(5): directions.append(Vector2.from_angle(-PI*0.5+TAU*i/5.0))
	for ring in range(1, 5):
		var points := PackedVector2Array()
		for direction in directions: points.append(center+direction*58.0*ring/4.0)
		points.append(points[0])
		draw_polyline(points, Color("29465c"), 1, true)
	var polygon := PackedVector2Array()
	for i in range(5):
		draw_line(center, center+directions[i]*58, Color("29465c"), 1, true)
		polygon.append(center+directions[i]*58*values[i])
		var p := center+directions[i]*76
		draw_string(ThemeDB.fallback_font, p-Vector2(32,-5), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 64, 12, Color("a8bdcc"))
	draw_colored_polygon(polygon, Color(cyan, 0.20))
	polygon.append(polygon[0])
	draw_polyline(polygon, cyan, 2, true)
	for i in range(5):
		var y := 20.0+i*29
		draw_string(ThemeDB.fallback_font, Vector2(205,y+10), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e5f1f7"))
		draw_rect(Rect2(282,y,285,8), Color("20354b"))
		draw_rect(Rect2(282,y,285*values[i],8), cyan)
		var text := "%.0f" % actual[i]
		if i == 0: text = "%.0f km/h" % (actual[i]*Config.HUD_SPEED_SCALE)
		if i == 4: text = "%.0f%%" % (clampf(260.0/actual[i],0.85,1.15)*100.0)
		draw_string(ThemeDB.fallback_font, Vector2(585,y+10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd16b"))
