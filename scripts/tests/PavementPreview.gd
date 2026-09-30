extends SceneTree

# Isolated design preview. Uses actual environment and vehicle assets;
# neither runtime rendering nor player saves are modified.
class RoadPanel:
	extends Node2D
	const Tracks = preload("res://scripts/catalog/track_catalog.gd")
	const Vehicles = preload("res://scripts/catalog/vehicle_catalog.gd")
	const Profile = preload("res://scripts/player_vehicle_profile.gd")
	var track_index := 0
	var option := 0
	var road_texture: ImageTexture
	var left: Texture2D
	var right: Texture2D
	var player: Texture2D
	var rng := RandomNumberGenerator.new()
	var palettes := [Color("15242e"), Color("343b3d"), Color("17212a"), Color("53595b")]

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var track: Dictionary = Tracks.all()[track_index]
		left = load(track.environment_left_sequence_paths[0])
		right = load(track.environment_right_sequence_paths[0])
		player = load(Vehicles.all()[0].texture_path)
		rng.seed = 20261001 + track_index
		var noise := FastNoiseLite.new()
		noise.seed = 20261001 + track_index
		noise.frequency = 0.7
		var surface := Image.create(780, 720, false, Image.FORMAT_RGB8)
		var base: Color = palettes[track_index]
		if option == 0: base = base.darkened(0.18)
		for y in range(720):
			for x in range(780):
				var amplitude: float = [0.018, 0.045, 0.07][option]
				var grain := noise.get_noise_2d(x, y) * amplitude
				var shade := base + Color(grain, grain, grain, 0)
				if track_index == 2 and option > 0:
					var distortion := noise.get_noise_2d(x * 0.02, y * 0.02) * 0.08
					var shine := exp(-pow(sin(x * 0.013 + distortion), 2.0) * 35.0) * clampf(noise.get_noise_2d(x * 0.03, y * 0.01) + 0.45, 0.0, 1.0)
					shade += Color(0.04, 0.07, 0.09, 0) * shine * (1.0 if option == 1 else 2.0)
				surface.set_pixel(x, y, shade)
		road_texture = ImageTexture.create_from_image(surface)
		queue_redraw()

	func _draw() -> void:
		if road_texture == null: return
		draw_rect(Rect2(0, 0, 1280, 720), Color("081725"))
		# Same 1:1 cropped source and road dimensions as the 720p game.
		draw_texture_rect_region(left, Rect2(0, 0, 220, 720), Rect2(left.get_width()-220, 0, 220, 720))
		draw_texture_rect_region(right, Rect2(1060, 0, 220, 720), Rect2(0, 0, 220, 720))
		draw_rect(Rect2(220, 0, 840, 720), Color("25353a"))
		draw_texture(road_texture, Vector2(250, 0))
		if option > 0 and track_index == 1:
			for lane in range(3):
				var x := 250.0 + lane * 260.0
				for y in range(-100 + lane*70, 720, 240):
					draw_line(Vector2(x+8, y), Vector2(x+252, y), Color(0.04, 0.06, 0.07, 0.5), 2.0)
				if option == 2:
					draw_rect(Rect2(x+25, 160 + lane*120, 180, 120), Color(0.08, 0.10, 0.11, 0.45))
		if option == 2 and track_index in [0, 3]:
			for y in range(160, 720, 280):
				draw_line(Vector2(270, y), Vector2(1010, y+12), Color(0.02, 0.03, 0.03, 0.25), 3.0)
		var edge := Color("45e6e0") if track_index == 0 else Color("e0ded0")
		for x in [250, 1030]: draw_line(Vector2(x, 0), Vector2(x, 720), edge, 8.0)
		for x in [510, 770]:
			for y in range(-32, 720, 140): draw_rect(Rect2(x-4, y, 8, 52), Color("e5eee8"))
		var profile: Dictionary = Vehicles.all()[0]
		var size: Vector2 = Profile.visual_size(profile, player.get_size())
		for position in [Vector2(380, 245), Vector2(900, 390), Vector2(640, 570)]:
			draw_set_transform(position, Profile.texture_rotation(profile))
			draw_texture_rect(player, Rect2(-size/2, size), false)
		draw_set_transform(Vector2.ZERO)
		for y in range(80, 380, 60):
			draw_circle(Vector2(640, y), 10, Color("ffd071"))
		for y in [415, 485]:
			draw_colored_polygon(PackedVector2Array([Vector2(490,y-14), Vector2(478,y+12), Vector2(502,y+12)]), Color("ff8138"))

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1320, 840)
	root.content_scale_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/previews/pavement"))
	for option in range(3):
		var board := Control.new()
		root.add_child(board)
		var background := ColorRect.new()
		background.color = Color("08111c")
		background.size = Vector2(1320, 840)
		board.add_child(background)
		var heading := Label.new()
		heading.text = ["A · 干净街机 / 轻纹理、强标线", "B · 克制材质 / 推荐：细沥青、工业接缝、湿地微反光", "C · 强环境表现 / 更粗颗粒、修补块与明显湿地反光"][option]
		heading.position = Vector2(20, 4)
		heading.add_theme_font_size_override("font_size", 24)
		board.add_child(heading)
		for index in range(4):
			var viewport := SubViewport.new()
			viewport.size = Vector2i(1280, 720)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			board.add_child(viewport)
			var panel := RoadPanel.new()
			panel.track_index = index
			panel.option = option
			viewport.add_child(panel)
			var picture := TextureRect.new()
			picture.texture = viewport.get_texture()
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.size = Vector2(640, 360)
			picture.position = Vector2(20+(index%2)*660, 80+(index/2)*400)
			board.add_child(picture)
			var title := Label.new()
			title.text = ["霓虹海岸 · 深色沥青", "货运港 · 工业铺装", "暴雨山道 · 湿沥青", "日出高速 · 浅灰沥青"][index]
			title.position = picture.position - Vector2(0, 30)
			title.add_theme_font_size_override("font_size", 20)
			board.add_child(title)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://docs/previews/pavement/option-%s.png" % ["A", "B", "C"][option])
		assert(root.get_texture().get_image().save_png(path) == OK)
		board.queue_free()
		await process_frame
	quit()
