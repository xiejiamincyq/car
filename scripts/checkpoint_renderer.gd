extends RefCounted

const Config = preload("res://scripts/game_config.gd")
const Geometry = preload("res://scripts/track_geometry.gd")

static func markers(progression: RaceProgression, distance: float, height: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var distances := progression.checkpoint_distances.duplicate()
	distances.append(progression.finish_distance)
	# RunState integrates distance as speed*dt*0.1; road integrates speed*dt*scroll.
	# A fixed world line therefore has this exact projection, not a looping offset.
	for index in distances.size():
		var y: float = Geometry.player_y(height) - (distances[index]-distance) * Config.ROAD_SCROLL_MULTIPLIER / 0.1
		if y < -100.0 or y > height + 50.0: continue
		result.append({"y":y,"index":index+1,"finish":index == distances.size()-1})
	return result

static func draw_markers(canvas: CanvasItem, progression: RaceProgression, distance: float, height: float, road_left: float, road_width: float, language: String, high_contrast: bool) -> void:
	var font := ThemeDB.fallback_font
	for mark in markers(progression,distance,height):
		var y: float = mark.y
		var accent := Color.WHITE if high_contrast else (Color("ffda77") if mark.finish else Color("63e5f2"))
		canvas.draw_rect(Rect2(road_left,y-18,road_width,36),Color("102d40"))
		canvas.draw_line(Vector2(road_left,y-20),Vector2(road_left+road_width,y-20),accent,3,true)
		canvas.draw_line(Vector2(road_left,y+20),Vector2(road_left+road_width,y+20),accent,3,true)
		var cell_width := road_width / 26.0
		for row in 2:
			for col in 26:
				if (row+col)%2 == 0: canvas.draw_rect(Rect2(road_left+col*cell_width,y-16+row*16,cell_width,16),Color(accent,0.85))
		var label: String = ("终点 / FINISH" if language == "zh" else "FINISH") if mark.finish else (("检查点 / CP %d" if language == "zh" else "CHECKPOINT %d") % mark.index)
		var board := Rect2(road_left+road_width*0.5-132,y-77,264,42)
		canvas.draw_rect(board,Color("102d40"))
		canvas.draw_rect(board,accent,false,2)
		canvas.draw_string(font,board.position+Vector2(12,29),label,HORIZONTAL_ALIGNMENT_CENTER,240,22,accent)
		for x in [road_left-12,road_left+road_width+12]:
			canvas.draw_line(Vector2(x,y-90),Vector2(x,y+22),accent,5,true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x,y-90),Vector2(x+24,y-80),Vector2(x,y-69)]),accent)
