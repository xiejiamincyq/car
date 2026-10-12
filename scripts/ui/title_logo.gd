extends Control
## Approved B coastal crest: native vectors, no additional asset dependency.
const NAVY := Color("07172a")
const CYAN := Color("65e9e0")
const GOLD := Color("efc56c")
var bold: FontVariation

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Neon Coast Rush"
	bold = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 1.5
	resized.connect(queue_redraw)
	queue_redraw()

func _poly(points: Array, top: Color, bottom: Color) -> void:
	var vertices := PackedVector2Array(points)
	var colors := PackedColorArray()
	for point in vertices: colors.append(top.lerp(bottom,clampf(point.y/150.0,0,1)))
	draw_polygon(vertices,colors)

func _rim(points: Array, color: Color, width := 1.0) -> void:
	var vertices := PackedVector2Array(points)
	vertices.append(vertices[0])
	draw_polyline(vertices,color,width,true)

func _plate(x: float, y: float, w: float, h: float, cut: float) -> Array:
	return [Vector2(x+cut,y),Vector2(x+w-cut,y),Vector2(x+w,y+cut),Vector2(x+w,y+h-cut),Vector2(x+w-cut,y+h),Vector2(x+cut,y+h),Vector2(x,y+h-cut),Vector2(x,y+cut)]

func _shadow(points: Array, offset := Vector2(0,5)) -> void:
	var shifted: Array = []
	for point in points: shifted.append(point+offset)
	draw_colored_polygon(PackedVector2Array(shifted),Color(0,0.015,0.03,0.55))

func _tracking(text: String, position: Vector2, font_size: int, spacing: float, color: Color) -> void:
	for letter in text:
		draw_string(bold,position,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
		position.x += bold.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+spacing

func _rush(position: Vector2, font_size: int, color: Color) -> void:
	var font: Font = bold
	draw_string_outline(font,position+Vector2(0,3),"RUSH",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color("020c19"))
	draw_string(font,position+Vector2(0,3),"RUSH",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("70542c"))
	draw_string_outline(font,position,"RUSH",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,1,Color("0b1c2b"))
	draw_string(font,position,"RUSH",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _fasteners(left: float, right: float, y: float) -> void:
	for x in [left,right]:
		draw_circle(Vector2(x,y),2.3,Color("687b84"))
		draw_line(Vector2(x-1.2,y),Vector2(x+1.2,y),NAVY,0.8,true)

func _coast(center: Vector2, radius: float, metal: Color) -> void:
	draw_circle(center,radius+2,Color("040f1d"))
	draw_arc(center,radius,0,TAU,64,metal,1.3,true)
	draw_arc(center,radius-4,0,TAU,64,Color("2a5767"),0.8,true)
	draw_circle(center+Vector2(0,-radius*0.28),radius*0.24,GOLD)
	for offset in [0,6,12]:
		draw_line(center+Vector2(-radius*0.68,offset),center+Vector2(radius*0.68,offset),Color("419baf"),0.9,true)
	var road := [center+Vector2(-2,-3),center+Vector2(3,-3),center+Vector2(12,radius-5),center+Vector2(-12,radius-5)]
	draw_colored_polygon(PackedVector2Array(road),NAVY)
	draw_line(center+Vector2(-2,-3),center+Vector2(-12,radius-5),metal,1,true)
	draw_line(center+Vector2(3,-3),center+Vector2(12,radius-5),metal,1,true)
	for offset in [3,12,21]:
		if offset < radius-7: draw_line(center+Vector2(1,offset),center+Vector2(1,offset+4),GOLD,1,true)

func _draw() -> void:
	if bold == null: return
	var factor := minf(size.x/384.0,size.y/150.0)
	if factor <= 0: return
	draw_set_transform((size-Vector2(384,150)*factor)*0.5,0,Vector2.ONE*factor)
	_rally()
	draw_set_transform(Vector2.ZERO)

func _rally() -> void:
	# A championship crest plus engraved wings: a softer, premium coastal identity.
	var wing := [Vector2(9,37),Vector2(106,21),Vector2(278,21),Vector2(375,37),Vector2(364,114),Vector2(263,122),Vector2(121,122),Vector2(20,114)]
	_shadow(wing)
	_poly(wing,Color("ad9563"),Color("63543e"))
	_rim(wing,Color("ffe7a0"),0.7)
	var wing_inner := [Vector2(15,42),Vector2(106,27),Vector2(278,27),Vector2(369,42),Vector2(358,109),Vector2(262,116),Vector2(122,116),Vector2(26,109)]
	_poly(wing_inner,Color("193342"),Color("081a2b"))
	for side in [-1,1]:
		for i in 4:
			var x: float = 192+side*(120+i*8)
			draw_line(Vector2(x,55),Vector2(x+side*20,105),Color("6e7667"),0.8,true)
	var crest := [Vector2(98,16),Vector2(134,7),Vector2(171,16),Vector2(167,111),Vector2(134,140),Vector2(101,111)]
	_shadow(crest,Vector2(2,3))
	_poly(crest,Color("f7d58c"),Color("8d7045"))
	var crest_inner := [Vector2(105,22),Vector2(134,14),Vector2(164,22),Vector2(160,106),Vector2(134,130),Vector2(108,106)]
	_poly(crest_inner,Color("164252"),Color("092130"))
	_rim(crest_inner,Color("eece86"),0.8)
	_coast(Vector2(134,67),29,Color("f4d793"))
	draw_line(Vector2(122,111),Vector2(146,111),GOLD,1,true)
	# Keep the full game identity dominant; the crest is a supporting mark.
	_tracking("NEON COAST",Vector2(181,48),15,0.9,Color("b8e5e1"))
	_rush(Vector2(181,95),43,Color("f6d58e"))
	draw_line(Vector2(183,105),Vector2(322,105),Color("ae9770"),0.8,true)
	_fasteners(34,351,83)
