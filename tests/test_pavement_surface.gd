extends SceneTree

const Surface = preload("res://scripts/pavement_surface.gd")
const Tracks = preload("res://scripts/catalog/track_catalog.gd")
const Config = preload("res://scripts/game_config.gd")
const Run = preload("res://scripts/run_state.gd")

func _init() -> void:
	for track in Tracks.all():
		assert(track.get("surface_id", &"") == track.id, "Each course must select its own approved pavement")
		var texture = Surface.texture_for(track.id)
		assert(texture != null and texture.get_width() == 780 and texture.get_height() == Surface.TILE_HEIGHT)
		var image: Image = texture.get_image()
		var seam := 0.0
		for x in range(image.get_width()):
			var top := image.get_pixel(x, 0)
			var bottom := image.get_pixel(x, image.get_height()-1)
			seam = maxf(seam, maxf(absf(top.r-bottom.r), maxf(absf(top.g-bottom.g), absf(top.b-bottom.b))))
		assert(seam <= 1.0/255.0, "All RGB channels must remain continuous across the repeat boundary")
	assert(Surface.texture_for(&"missing") == null, "Unknown surfaces must preserve the existing solid fallback")
	for distance in [0.0, 100.0, 800.0, 834.7, 40000.0]:
		for speed in [0.0, 80.0, 200.0, 400.0, 500.0]:
			var before: float = Surface.scroll_offset(distance)
			var after: float = Surface.scroll_offset(distance + speed * 0.1 * 0.1)
			assert(is_equal_approx(fposmod(after-before, Surface.TILE_HEIGHT), speed*0.1*Config.ROAD_SCROLL_MULTIPLIER), "Pavement must match stationary obstacles at all speeds, including wraparound and stopped player")
	var run := Run.new(100.0, 0.0)
	run.start()
	var before := Surface.scroll_offset(run.distance)
	run.tick(0.25, 760.0, 760.0)
	assert(is_equal_approx(Surface.scroll_offset(run.distance)-before, 760.0*0.25*Config.ROAD_SCROLL_MULTIPLIER), "Real race distance uses scaled units: pavement must still move at the same speed as white lines and cones")
	var paused_offset := Surface.scroll_offset(run.distance)
	run.toggle_pause()
	run.tick(1.0, 760.0, 760.0)
	assert(Surface.scroll_offset(run.distance) == paused_offset, "Pausing must freeze pavement displacement")
	quit()
