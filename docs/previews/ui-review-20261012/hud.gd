extends Control
## Static proposal data is read from an isolated Main fixture, not a new gameplay HUD.
const Route = preload("res://scripts/ui/race_route_map.gd")
const PreviewSkin = preload("res://docs/previews/ui-review-20261012/skin.gd")
var main
var font: Font
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	var route := Route.new()
	add_child(route)
	route.position = Vector2(0,174)
	route.size = Vector2(224,252)
	route.present(main.run.distance,main.run.progression.finish_distance,main.run.progression.checkpoint_distances,main.language)
func text(value: String, position: Vector2, dimensions: Vector2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font,position,value,alignment,dimensions.x,font_size,color)
func panel(rect: Rect2) -> void:
	draw_style_box(PreviewSkin.box(Color(0.025,0.07,0.10,0.70),Color(0.23,0.5,0.56,0.5),0),rect)
func bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_style_box(PreviewSkin.box(Color("1b3542"),Color.TRANSPARENT,0),rect)
	var filled := rect
	filled.size.x *= clampf(ratio,0,1)
	draw_style_box(PreviewSkin.box(color,Color.TRANSPARENT,0),filled)
func dial(center: Vector2, radius: float, ratio: float, color: Color) -> void:
	var start := deg_to_rad(140)
	var sweep := deg_to_rad(260)
	draw_arc(center,radius,start,start+sweep,64,Color("2c4b58"),6,true)
	draw_arc(center,radius,start,start+sweep*ratio,64,color,4,true)
	for index in 13:
		var direction := Vector2.from_angle(start+sweep*index/12)
		draw_line(center+direction*(radius-7),center+direction*(radius-1),color if index/12.0 <= ratio else Color("708e9a"),1.5,true)
func _draw() -> void:
	if font == null: return
	var zh: bool = main.language == "zh"
	panel(Rect2(0,0,224,62))
	text("赛段 1" if zh else "STAGE 1",Vector2(12,25),Vector2(200,30),20,PreviewSkin.WHITE)
	text("比赛中" if zh else "RACING",Vector2(12,49),Vector2(200,30),16,PreviewSkin.CYAN)
	panel(Rect2(0,72,224,94))
	text("完整度" if zh else "INTEGRITY",Vector2(12,96),Vector2(130,30),17,PreviewSkin.WHITE)
	text("%d%%" % main.integrity.current,Vector2(145,96),Vector2(65,30),20,PreviewSkin.CYAN,HORIZONTAL_ALIGNMENT_RIGHT)
	bar(Rect2(12,107,198,12),main.integrity.current/100,PreviewSkin.CYAN)
	text("超载就绪" if zh else "BOOST READY",Vector2(12,146),Vector2(198,30),16,PreviewSkin.GOLD)
	panel(Rect2(size.x/2-208,0,416,62))
	text("%d / %d m" % [main.run.distance,main.run.progression.finish_distance],Vector2(size.x/2-194,24),Vector2(388,30),18,PreviewSkin.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	bar(Rect2(size.x/2-194,40,388,10),main.run.distance/main.run.progression.finish_distance,PreviewSkin.CYAN)
	panel(Rect2(size.x-224,0,224,116))
	text("得分" if zh else "SCORE",Vector2(size.x-210,24),Vector2(194,30),16,PreviewSkin.CYAN)
	text("%s" % main.run.score,Vector2(size.x-210,67),Vector2(194,44),36,PreviewSkin.GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	text(("金币  %d" if zh else "COINS  %d") % main.run.coins,Vector2(size.x-210,98),Vector2(194,30),20,PreviewSkin.WHITE,HORIZONTAL_ALIGNMENT_RIGHT)
	panel(Rect2(0,size.y-226,224,226))
	text("速度" if zh else "SPEED",Vector2(12,size.y-200),Vector2(200,26),17,PreviewSkin.CYAN)
	var center := Vector2(76,size.y-118)
	dial(center,60,clampf(main.drive.speed/(main.drive.max_speed+main.GameConfig.OVERDRIVE_SPEED_BONUS),0,1),PreviewSkin.CYAN)
	text("%d" % roundi(main.drive.speed*main.GameConfig.HUD_SPEED_SCALE),Vector2(28,size.y-102),Vector2(96,36),36,PreviewSkin.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	text("km/h",Vector2(34,size.y-78),Vector2(88,24),14,Color("abc2cd"),HORIZONTAL_ALIGNMENT_CENTER)
	dial(Vector2(176,size.y-116),25,main.run.fuel/100,PreviewSkin.GOLD)
	text("燃油" if zh else "FUEL",Vector2(142,size.y-74),Vector2(68,30),16,PreviewSkin.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	text("%d%%" % main.run.fuel,Vector2(150,size.y-48),Vector2(60,30),22,PreviewSkin.WHITE,HORIZONTAL_ALIGNMENT_RIGHT)
	bar(Rect2(12,size.y-26,198,12),main.run.fuel/100,PreviewSkin.GOLD)
