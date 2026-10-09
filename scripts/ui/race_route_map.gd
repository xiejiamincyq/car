extends Control
## Passive course overview: bottom is start, top is finish. No invented road bends.
const CYAN := Color("63e5f2")
const GOLD := Color("ffda77")
const MUTED := Color("739ba9")
const COMPLETE := Color("76edb6")
var _distance := 0.0
var _finish := 1.0
var _checkpoints: Array[float] = []
var _language := "zh"
var _style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.02, 0.055, 0.085, 0.70)
	_style.set_corner_radius_all(4)
	resized.connect(queue_redraw)

func present(distance: float, finish: float, checkpoints: Array, language: String) -> void:
	_finish = maxf(1.0, finish)
	_distance = clampf(distance, 0.0, _finish)
	_checkpoints.assign(checkpoints)
	_language = language
	queue_redraw()

func presentation() -> Dictionary:
	var marks: Array[Dictionary] = []
	var next_distance := _finish
	var next_index := 0
	for index in _checkpoints.size():
		var distance: float = _checkpoints[index]
		marks.append({"progress":clampf(distance / _finish,0.0,1.0),"passed":_distance >= distance,"index":index + 1})
		if next_index == 0 and distance > _distance:
			next_distance = distance
			next_index = index + 1
	return {"progress":_distance/_finish,"checkpoints":marks,"next_index":next_index,"remaining":maxf(0.0,next_distance-_distance)}

func _route_point(progress: float) -> Vector2:
	return Vector2(62.0, lerpf(size.y - 38.0, 62.0, progress))

func _label(text: String, position: Vector2, font_size: int, color: Color = MUTED, width: float = 144.0) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func _draw() -> void:
	if _style == null or size.y < 150.0: return
	var state := presentation()
	draw_style_box(_style, Rect2(Vector2.ZERO,size))
	draw_line(Vector2(0,1),Vector2(size.x,1),Color(CYAN,0.45),2,true)
	_label("路线 / ROUTE" if _language == "zh" else "ROUTE",Vector2(16,24),14,CYAN)
	_label("%03d%%" % roundi(state.progress * 100.0),Vector2(size.x-70,24),18,Color.WHITE,66)
	var start := _route_point(0.0)
	var finish := _route_point(1.0)
	draw_line(start,finish,Color("183645"),26,true)
	for offset in [-12.0,12.0]: draw_line(start+Vector2(offset,0),finish+Vector2(offset,0),MUTED,1,true)
	draw_line(start,_route_point(state.progress),Color(CYAN,0.4),10,true)
	_label("起点" if _language == "zh" else "START",start+Vector2(28,5),12)
	_label("终点" if _language == "zh" else "FINISH",finish+Vector2(28,-3),12,GOLD)
	for row in 2:
		for col in 4:
			draw_rect(Rect2(finish+Vector2(-12+col*6,-12+row*6),Vector2(6,6)),Color.WHITE if (row+col)%2 == 0 else Color("142633"))
	for mark in state.checkpoints:
		var point := _route_point(mark.progress)
		var accent: Color = COMPLETE if mark.passed else GOLD
		draw_line(point-Vector2(18,0),point+Vector2(18,0),accent,2,true)
		draw_circle(point,5,accent)
		_label("CP %d" % mark.index,point+Vector2(28,5),14,accent)
		if mark.passed: _label("✓",point+Vector2(96,5),15,COMPLETE,20)
	var player := _route_point(state.progress)
	draw_circle(player,12,Color("102d40"))
	draw_colored_polygon(PackedVector2Array([player+Vector2(0,-10),player+Vector2(-7,7),player+Vector2(7,7)]),Color.WHITE)
	draw_polyline(PackedVector2Array([player+Vector2(0,-10),player+Vector2(-7,7),player+Vector2(7,7),player+Vector2(0,-10)]),CYAN,2,true)
	var target: String = "CP %d" % state.next_index if state.next_index > 0 else ("终点" if _language == "zh" else "FINISH")
	_label("%s · %d m" % [target,ceili(state.remaining)],Vector2(16,size.y-12),13,GOLD,size.x-28)
