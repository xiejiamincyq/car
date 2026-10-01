extends SceneTree

const Surface = preload("res://scripts/pavement_surface.gd")

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/pavement"))
	for index in range(Surface.IDS.size()):
		var noise := FastNoiseLite.new()
		noise.seed = 20261001+index
		noise.frequency = 0.7
		var image := Image.create(780, Surface.TILE_HEIGHT, false, Image.FORMAT_RGB8)
		for y in range(Surface.TILE_HEIGHT):
			var angle := TAU*y/Surface.TILE_HEIGHT
			var circle_y := cos(angle)*Surface.TILE_HEIGHT/TAU
			var circle_z := sin(angle)*Surface.TILE_HEIGHT/TAU
			for x in range(780):
				var grain := noise.get_noise_3d(x, circle_y, circle_z)
				var broad := noise.get_noise_3d(x*0.016, circle_y*0.02, circle_z*0.02)
				var shade: Color = [Color("162a37"), Color("303c40"), Color("15232e"), Color("55534f")][index]
				shade += Color(1,1,1,0)*grain*(0.07 if index == 1 else 0.04)
				if index == 1:
					var row := floori(y/240.0)
					var shifted := x+(row%2)*130
					shade += Color(1,1,0.9,0)*sin((row%2)*1.7+floor(shifted/260.0))*0.016
					if shifted%260 < 2 or y%240 < 2: shade = shade.darkened(0.28*0.65)
					var tire := minf(absf(float(x%260)-95),absf(float(x%260)-165))
					if tire < 10: shade = shade.darkened(0.08*0.65)
				elif index == 2:
					var coarse := noise.get_noise_3d(x*0.3,circle_y*0.3,circle_z*0.3)
					shade += Color(0.8,0.95,1,0)*coarse*0.035
					if broad > 0.15:
						shade = shade.darkened(0.15*0.65)
						shade += Color(0.02,0.045,0.065,0)*broad*0.65
					if minf(x,779-x) < 26 and coarse > 0.15: shade = Color("414a4d").lerp(shade,0.35)
				elif index == 0:
					shade = shade.darkened(maxf(0,broad)*0.09*0.65)
				else:
					shade += Color(0.055,0.035,0.012,0)*exp(-minf(x,779-x)/65.0)
				image.set_pixel(x,y,shade)
		# Keep boundary pixels continuous, including industrial expansion joints.
		for x in range(780): image.set_pixel(x,Surface.TILE_HEIGHT-1,image.get_pixel(x,0))
		var path := ProjectSettings.globalize_path("res://assets/pavement/%s.png" % Surface.IDS[index])
		assert(image.save_png(path) == OK)
		print("BAKED ", Surface.IDS[index], " 780x", Surface.TILE_HEIGHT)
	quit()
