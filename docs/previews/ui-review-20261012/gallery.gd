extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]): quit(2); return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.content_scale_size = Vector2i(1600,1510)
	root.size = Vector2i(1600,1510)
	DisplayServer.window_set_size(root.size)
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("05101c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var heading := Label.new()
	heading.position = Vector2(24,16); heading.size = Vector2(1552,50)
	heading.text = "NEON COAST RUSH  ·  全界面改动预览"
	heading.add_theme_font_size_override("font_size",30)
	heading.add_theme_color_override("font_color",Color("edc77d"))
	canvas.add_child(heading)
	var states := ["title","garage","tour","settings","clear","hud"]
	var titles := ["01 标题 · B海岸巡回徽章","02 选车 · 持续选中标识 / 车型缩略图","03 赛道 · 场景缩略图 / 清晰解锁状态","04 设置 · 音量与功能项分区","05 结算 · 评分优先 / 次要数据降级","06 HUD · 两侧信息归位 / 燃油长条"]
	for index in states.size():
		var texture := TextureRect.new()
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.texture = ImageTexture.create_from_image(Image.load_from_file(args[0].path_join(states[index]+"-zh-720.png")))
		texture.position = Vector2(24+(index%2)*788,88+(index/2)*470)
		texture.size = Vector2(764,429.75)
		canvas.add_child(texture)
		var caption := Label.new()
		caption.text = titles[index]
		caption.position = texture.position+Vector2(0,433)
		caption.size = Vector2(764,32)
		caption.add_theme_font_size_override("font_size",19)
		caption.add_theme_color_override("font_color",Color("dbe9eb"))
		canvas.add_child(caption)
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	if pixels.get_size() != Vector2i(1600,1510) or pixels.save_png(args[1]) != OK: quit(3); return
	print("UI_GALLERY_COMPLETE ",args[1])
	canvas.queue_free(); await process_frame
	quit(0)
