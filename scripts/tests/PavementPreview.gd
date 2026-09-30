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
	var distinct := false
	var coherent := false
	var left_pixels: Image
	var right_pixels: Image
	var left_light := PackedColorArray()
	var right_light := PackedColorArray()
	const MATERIALS := [["wood", "concrete", "gravel", "brick"], ["wood", "steel", "mud", "stone"], ["sand", "grate", "rock", "brick"]]
	const MATERIAL_LABELS := [["木栈道", "大板混凝土", "砂砾山路", "红褐砖路"], ["灰木栈道", "钢板甲板", "湿泥车辙", "暖色石板"], ["压实砂地", "金属格栅", "碎岩山路", "旧砖街道"]]
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
		left_pixels = left.get_image()
		right_pixels = right.get_image()
		if coherent:
			for y in range(720):
				left_light.append(edge_light(left_pixels, left_pixels.get_width()-42, y))
				right_light.append(edge_light(right_pixels, 42, y))
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
				if distinct:
					shade = material_color(x, y, noise)
				if coherent:
					shade = contextual_color(x, y, noise)
				if not distinct and not coherent and track_index == 2 and option > 0:
					var distortion := noise.get_noise_2d(x * 0.02, y * 0.02) * 0.08
					var shine := exp(-pow(sin(x * 0.013 + distortion), 2.0) * 35.0) * clampf(noise.get_noise_2d(x * 0.03, y * 0.01) + 0.45, 0.0, 1.0)
					shade += Color(0.04, 0.07, 0.09, 0) * shine * (1.0 if option == 1 else 2.0)
				surface.set_pixel(x, y, shade)
		road_texture = ImageTexture.create_from_image(surface)
		queue_redraw()

	func edge_light(source: Image, x: int, y: int) -> Color:
		var total := Color(0, 0, 0, 0)
		for offset in [-32, -16, 0, 16, 32]:
			total += source.get_pixel(x, clampi(y + offset, 0, source.get_height()-1))
		return total / 5.0

	func contextual_color(x: int, y: int, noise: FastNoiseLite) -> Color:
		var base: Color = [Color("162a37"), Color("303c40"), Color("15232e"), Color("55534f")][track_index]
		var strength: float = [0.65, 1.0, 1.4][option]
		var grain := noise.get_noise_2d(x, y)
		var broad := noise.get_noise_2d(x * 0.016, y * 0.02)
		var edge_distance := minf(x, 779-x)
		var edge_falloff := exp(-edge_distance / 65.0)
		var shade := base + Color(1, 1, 1, 0) * grain * (0.07 if track_index == 1 else 0.04)
		# Sample the actual background's near-road lighting at the same height.
		var lighting := left_light[y] if x < 390 else right_light[y]
		shade += Color(lighting.r, lighting.g, lighting.b, 0) * edge_falloff * strength * 0.28
		if track_index == 1:
			# Staggered heavy concrete slabs; cool, worn and dark like the yard.
			var row := floori(y / 240.0)
			var shifted := x + (row % 2) * 130
			shade += Color(1, 1, 0.9, 0) * sin(row*1.7 + floor(shifted/260.0)) * 0.016
			if shifted % 260 < 2 or y % 240 < 2: shade = shade.darkened(0.28 * strength)
			var stain := minf(pow((x-160)/70.0, 2.0)+pow((y-180)/80.0, 2.0), pow((x-660)/55.0, 2.0)+pow((y-440)/90.0, 2.0))
			if option > 0 and stain < 1.0 and broad < 0.0: shade = shade.darkened(0.15 * strength * (1.0-stain))
			# Tire wear is a subtle stain, not a new lane barrier.
			var tire := minf(absf(float(x % 260)-95), absf(float(x % 260)-165))
			if tire < 10: shade = shade.darkened(0.08 * strength)
		elif track_index == 2:
			var coarse := noise.get_noise_2d(x*0.3, y*0.3)
			shade += Color(0.8, 0.95, 1, 0) * coarse * 0.035
			if broad > 0.15:
				shade = shade.darkened(0.15 * strength)
				shade += Color(0.02, 0.045, 0.065, 0) * broad * strength
			# Loose aggregate remains at the shoulder, outside the driving lanes.
			if edge_distance < 26 and coarse > 0.15:
				shade = Color("414a4d").lerp(shade, 0.35)
		elif track_index == 0:
			shade = shade.darkened(maxf(0.0, broad) * 0.09 * strength)
			if edge_distance < 12 and grain > 0.25 and option > 0:
				shade = shade.lerp(Color("79745f"), 0.25)
		else:
			# Clean, warm morning asphalt; narrow seams, not stone paving.
			shade += Color(0.055, 0.035, 0.012, 0) * edge_falloff
			if option == 2 and y % 360 < 2: shade = shade.darkened(0.15)
		return shade

	func material_color(x: int, y: int, noise: FastNoiseLite) -> Color:
		var grain := noise.get_noise_2d(x, y)
		var broad := noise.get_noise_2d(x * 0.03, y * 0.03)
		var material: String = MATERIALS[option][track_index]
		var shade := Color("62504a")
		match material:
			"wood":
				var row := floori(y / 64.0)
				var stagger := (row % 2) * 130
				var seam := y % 64 < 3 or (x + stagger) % 260 < 3
				var grain_line := sin(y * 1.4 + sin(x * 0.012) * 0.6) * 0.025
				shade = Color("72523b") if option == 0 else Color("666153")
				shade += Color(1, 0.8, 0.6, 0) * (broad * 0.035 + grain_line + sin(row * 2.13) * 0.035)
				if seam: shade = shade.darkened(0.5)
			"concrete":
				shade = Color("586169") + Color(grain, grain, grain, 0) * 0.05
				shade += Color(1, 1, 1, 0) * sin(floor(x / 260.0) * 2.0 + floor(y / 180.0)) * 0.025
				if x % 260 < 3 or y % 180 < 3: shade = shade.darkened(0.55)
			"steel", "grate":
				shade = Color("354a57") + Color(grain, grain, grain, 0) * 0.025
				if material == "grate":
					shade = Color("17262c") if x % 16 > 3 and y % 16 > 3 else Color("53656b")
				else:
					var rib := (x + y) % 28 < 3 and (x - y + 2000) % 42 < 16
					if rib: shade = shade.lightened(0.15)
				if x % 260 < 4 or y % 180 < 4: shade = Color("111b21")
			"gravel", "rock":
				shade = Color("514c42") if material == "gravel" else Color("494f51")
				var stones := noise.get_noise_2d(x * 0.25, y * 0.25)
				shade += Color(1, 1, 0.9, 0) * (stones * 0.13 + grain * 0.035 + broad * 0.03)
				if material == "rock" and stones < -0.35: shade = shade.darkened(0.25)
			"mud", "sand":
				shade = Color("514331") if material == "mud" else Color("8b7852")
				shade += Color(1, 0.9, 0.7, 0) * (broad * 0.045 + grain * 0.035)
				var rut := minf(absf(float(x % 260) - 90), absf(float(x % 260) - 170))
				if rut < 13.0 + broad * 7.0: shade = shade.darkened(0.18 if material == "sand" else 0.35)
				if material == "mud" and broad > 0.28 and rut < 30: shade = Color("303d40")
			"brick", "stone":
				var row := floori(y / (44.0 if material == "brick" else 100.0))
				var height := 44 if material == "brick" else 100
				var width := 120 if material == "brick" else 195
				var shifted := x + (row % 2) * (width / 2)
				shade = Color("73513e") if material == "brick" else Color("716857")
				shade += Color(1, 0.85, 0.65, 0) * (grain * 0.035 + sin(row * 2.7 + floor(shifted / float(width))) * 0.035)
				if y % height < 3 or shifted % width < 3: shade = shade.darkened(0.4)
		return shade

	func _draw() -> void:
		if road_texture == null: return
		draw_rect(Rect2(0, 0, 1280, 720), Color("081725"))
		# Same 1:1 cropped source and road dimensions as the 720p game.
		draw_texture_rect_region(left, Rect2(0, 0, 220, 720), Rect2(left.get_width()-220, 0, 220, 720))
		draw_texture_rect_region(right, Rect2(1060, 0, 220, 720), Rect2(0, 0, 220, 720))
		draw_rect(Rect2(220, 0, 840, 720), Color("25353a"))
		draw_texture(road_texture, Vector2(250, 0))
		if coherent:
			var curb: Color = [Color("23333f"), Color("30393c"), Color("242f34"), Color("797369")][track_index]
			for x in [220, 1030]:
				draw_rect(Rect2(x, 0, 30, 720), curb)
				for y in range(0, 720, 100):
					draw_line(Vector2(x,y), Vector2(x+30,y), curb.darkened(0.4), 2)
				if track_index == 1:
					for y in range(90, 650, 180):
						for stripe in range(3):
							draw_line(Vector2(x+2,y+stripe*16), Vector2(x+28,y+stripe*16-12), Color("8d783a"), 5)
		if not distinct and not coherent and option > 0 and track_index == 1:
			for lane in range(3):
				var x := 250.0 + lane * 260.0
				for y in range(-100 + lane*70, 720, 240):
					draw_line(Vector2(x+8, y), Vector2(x+252, y), Color(0.04, 0.06, 0.07, 0.5), 2.0)
				if option == 2:
					draw_rect(Rect2(x+25, 160 + lane*120, 180, 120), Color(0.08, 0.10, 0.11, 0.45))
		if not distinct and not coherent and option == 2 and track_index in [0, 3]:
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
	var distinct := OS.get_cmdline_user_args().has("distinct")
	var coherent := OS.get_cmdline_user_args().has("coherent")
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
		if distinct:
			heading.text = ["新版 A · 木栈道 / 混凝土 / 砂砾 / 砖路", "新版 B · 木栈道 / 钢板 / 湿泥车辙 / 石板", "新版 C · 压实砂地 / 金属格栅 / 碎岩 / 旧砖"][option]
		if coherent:
			heading.text = ["场景匹配 A · 清洁路面 / 低磨损与柔和环境光", "场景匹配 B · 日常使用 / 工业接缝、湿地与晨光", "场景匹配 C · 强化环境 / 更明显的磨损、潮湿与光照"][option]
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
			panel.distinct = distinct
			panel.coherent = coherent
			viewport.add_child(panel)
			var picture := TextureRect.new()
			picture.texture = viewport.get_texture()
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.size = Vector2(640, 360)
			picture.position = Vector2(20+(index%2)*660, 80+(index/2)*400)
			board.add_child(picture)
			var title := Label.new()
			title.text = ["霓虹海岸 · 深色沥青", "货运港 · 工业铺装", "暴雨山道 · 湿沥青", "日出高速 · 浅灰沥青"][index]
			if distinct:
				title.text = ["霓虹海岸", "货运港", "暴雨山道", "日出高速"][index] + " · " + RoadPanel.MATERIAL_LABELS[option][index]
			if coherent:
				title.text = ["霓虹海岸 · 蓝紫灯光 / 深色滨海沥青", "货运港 · 冷灰混凝土 / 暖灯与警戒路肩", "暴雨山道 · 湿冷粗沥青 / 碎石路肩", "日出高速 · 晨光浅灰沥青 / 规整路肩"][index]
			title.position = picture.position - Vector2(0, 30)
			title.add_theme_font_size_override("font_size", 20)
			board.add_child(title)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var prefix := "distinct" if distinct else "option"
		if coherent: prefix = "coherent"
		var path := ProjectSettings.globalize_path("res://docs/previews/pavement/%s-%s.png" % [prefix, ["A", "B", "C"][option]])
		assert(root.get_texture().get_image().save_png(path) == OK)
		board.queue_free()
		await process_frame
	quit()
