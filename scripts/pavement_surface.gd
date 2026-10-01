class_name PavementSurface
extends RefCounted

const Config = preload("res://scripts/game_config.gd")
const Scroller = preload("res://scripts/environment_scroller.gd")
const TILE_HEIGHT := 960
# RunState stores speed * seconds * 0.1; road geometry uses unscaled speed.
const WORLD_UNITS_PER_RACE_DISTANCE := 10.0
const IDS := [&"neon_coast", &"freight_harbor", &"storm_ridge", &"sunrise_express"]
static var _textures: Dictionary = {}
static var _lights: Dictionary = {}

static func texture_for(id: StringName) -> Texture2D:
	if id not in IDS: return null
	if not _textures.has(id):
		var path := "res://assets/pavement/%s.png" % id
		_textures[id] = load(path) if ResourceLoader.exists(path) else null
	return _textures[id]

static func scroll_offset(distance: float, period: float = TILE_HEIGHT) -> float:
	return fposmod(distance * WORLD_UNITS_PER_RACE_DISTANCE * Config.ROAD_SCROLL_MULTIPLIER, period)

static func draw_surface(canvas: Node2D, track: Dictionary, left: float, height: float, distance: float, high_contrast: bool, left_backgrounds: Array, right_backgrounds: Array) -> void:
	if high_contrast: return
	var id := StringName(track.get("surface_id", &""))
	var texture := texture_for(id)
	if texture == null: return
	var width := Config.ROAD_HALF_WIDTH * 2.0
	var tile_y := scroll_offset(distance) - TILE_HEIGHT
	while tile_y < height:
		canvas.draw_texture_rect(texture, Rect2(left, tile_y, width, TILE_HEIGHT), false)
		tile_y += TILE_HEIGHT
	var index := IDS.find(id)
	var curb: Color = [Color("23333f"), Color("30393c"), Color("242f34"), Color("797369")][index]
	for x in [left-30.0, left+width]:
		canvas.draw_rect(Rect2(x, 0, 30, height), curb)
		var y := scroll_offset(distance, 100.0)-100.0
		while y < height:
			canvas.draw_line(Vector2(x,y), Vector2(x+30,y), curb.darkened(0.4), 2)
			y += 100
		if id == &"freight_harbor":
			y = scroll_offset(distance, 180.0)-180.0
			while y < height:
				for stripe in range(3):
					canvas.draw_line(Vector2(x+2,y+stripe*16), Vector2(x+28,y+stripe*16-12), Color("8d783a"), 5)
				y += 180
	# Light is matched to the environment sequence. The solid road texture and
	# curb marks above use actual world displacement, never background progress.
	for side in range(2):
		var backgrounds: Array = left_backgrounds if side == 0 else right_backgrounds
		if backgrounds.is_empty(): continue
		var tiles := Scroller.sequence_tiles(distance, float(track.finish_distance), height, backgrounds[0].get_height(), backgrounds.size())
		for tile in tiles:
			var lighting := light_for(backgrounds[int(tile.index)], side == 0)
			canvas.draw_texture_rect(lighting, Rect2(left if side == 0 else left+width*0.5, tile.y, width*0.5, lighting.get_height()), false)

static func light_for(background: Texture2D, left_side: bool) -> Texture2D:
	var key := "%s:%s" % [background.resource_path, left_side]
	if _lights.has(key): return _lights[key]
	var source := background.get_image()
	var image := Image.create(32, source.get_height(), false, Image.FORMAT_RGBA8)
	var sample_x := source.get_width()-42 if left_side else 42
	for y in range(image.get_height()):
		var color := Color(0, 0, 0, 0)
		for offset in [-32, -16, 0, 16, 32]:
			color += source.get_pixel(sample_x, clampi(y+offset, 0, source.get_height()-1))
		color /= 5.0
		for x in range(32):
			var distance_from_edge := float(x if left_side else 31-x) * 390.0/31.0
			var light := Color(color.r, color.g, color.b, exp(-distance_from_edge/65.0)*0.65*0.28)
			image.set_pixel(x, y, light)
	var texture := ImageTexture.create_from_image(image)
	_lights[key] = texture
	return texture
