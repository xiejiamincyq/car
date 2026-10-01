extends RefCounted

static func draw_pickup(canvas: CanvasItem, center: Vector2, repair: bool, high_contrast: bool = false) -> void:
	var accent := Color("64e9fb") if repair else Color("ffd16b")
	if high_contrast: accent = Color.WHITE if repair else Color.YELLOW
	canvas.draw_circle(center, 32, Color(accent, 0.14))
	var body := Rect2(center+Vector2(-23,-20), Vector2(46,44))
	canvas.draw_rect(body.grow(2), Color("04101c"))
	canvas.draw_rect(body, Color("164154") if repair else Color("755321"))
	canvas.draw_rect(body, accent, false, 2)
	# Handle and lid make both objects solid containers, not abstract badges.
	canvas.draw_polyline(PackedVector2Array([center+Vector2(-9,-20),center+Vector2(-9,-29),center+Vector2(9,-29),center+Vector2(9,-20)]), accent, 4, true)
	if repair:
		canvas.draw_line(center+Vector2(-23,-10),center+Vector2(23,-10),accent,2,true)
		# Gear silhouette: alternating tooth radii and a hollow hub.
		var gear := PackedVector2Array()
		var hub := center+Vector2(10,7)
		for i in range(32):
			gear.append(hub+Vector2.from_angle(TAU*i/32.0)*(13.0 if i%4 in [0,1] else 10.0))
		canvas.draw_colored_polygon(gear, accent)
		canvas.draw_circle(hub,5,Color("164154"))
		# Open-ended wrench crossing the toolbox, separate from the gear.
		canvas.draw_line(center+Vector2(-14,16),center+Vector2(-3,-1),Color.WHITE,5,true)
		canvas.draw_arc(center+Vector2(-2,-3),7,-0.2,PI+0.5,16,Color.WHITE,4,true)
		canvas.draw_circle(center+Vector2(-14,16),3,Color.WHITE)
	else:
		canvas.draw_rect(Rect2(center+Vector2(11,-28),Vector2(10,7)),accent)
		canvas.draw_line(center+Vector2(-15,-9),center+Vector2(14,17),Color(accent,0.3),2,true)
		canvas.draw_line(center+Vector2(15,-9),center+Vector2(-14,17),Color(accent,0.3),2,true)
		# Fuel droplet on the canister face.
		canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-8),center+Vector2(-7,3),center+Vector2(-7,9),center+Vector2(0,13),center+Vector2(7,9),center+Vector2(7,3)]),accent)
		canvas.draw_line(center+Vector2(-3,4),center+Vector2(-3,8),Color.WHITE,2,true)
