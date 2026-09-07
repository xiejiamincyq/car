extends SceneTree

# Standalone layout proposals only. Never loads or writes a player profile.
class Preview:
	extends Node2D
	var font := SystemFont.new()
	var ink := Color("e6f4fa")
	var muted := Color("95afc3")
	var cyan := Color("50dcf1")
	var gold := Color("ffd071")

	func _ready() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])

	func label_at(x: float, y: float, text: String, size: int = 20, color: Color = Color("e6f4fa")) -> void:
		draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func panel(rect: Rect2, color: Color, border: Color = Color("254359")) -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(14)
		style.set_border_width_all(1)
		style.border_color = border
		draw_style_box(style, rect)

	func bar(x: float, y: float, title: String, value: int, maximum: int, detail: String) -> void:
		label_at(x, y, title, 19)
		label_at(x + 264, y, "%d / %d" % [value, maximum], 20, cyan)
		draw_rect(Rect2(x, y + 14, 352, 5), Color("233d50"))
		draw_rect(Rect2(x, y + 14, 352.0 * value / maximum, 5), cyan)
		label_at(x, y + 43, detail, 14, muted)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1440, 900), Color("07111e"))
		label_at(42, 48, "结算评分卡 · 三种布局预览", 28)
		label_at(42, 78, "P6 设计选择 / 示例数据，不是本局成绩 / 保留当前霓虹配色", 16, muted)
		for index in range(3):
			var x := 36.0 + index * 472.0
			panel(Rect2(x, 110, 424, 724), Color("101f30"))
			label_at(x + 26, 153, ["A · 街机大徽章", "B · 四项成绩卡（推荐）", "C · 驾驶复盘表"][index], 23, cyan)
			label_at(x + 26, 185, "霓虹海岸  /  标准  /  完赛", 16, muted)
			panel(Rect2(x + 24, 709, 376, 46), Color("173e50"), cyan)
			label_at(x + 146, 739, "再跑一次  ↵", 20)
			panel(Rect2(x + 24, 765, 376, 42), Color("12283a"))
			label_at(x + 157, 793, "返回地图", 18, muted)
			if index == 0:
				label_at(x + 84, 316, "S", 108, gold)
				label_at(x + 193, 290, "92 / 100", 34)
				label_at(x + 197, 321, "本赛道最佳  92 · S", 16, gold)
				bar(x + 36, 372, "用时", 36, 40, "66.0 秒 · 满分目标 ≤ 60 秒")
				bar(x + 36, 452, "超车", 18, 20, "11 辆 · 目标 12 辆")
				bar(x + 36, 532, "避撞", 20, 20, "0 次碰撞 · 每次扣 4 分")
				bar(x + 36, 612, "金币", 18, 20, "54 枚 · 目标 60 枚")
			elif index == 1:
				label_at(x + 28, 267, "S", 65, gold)
				label_at(x + 103, 256, "92", 49)
				label_at(x + 177, 253, "/ 100", 23, muted)
				label_at(x + 28, 303, "新最佳评分  ·  92 分", 18, gold)
				var names := ["用时", "超车", "避撞", "金币"]
				var scores := ["36 / 40", "18 / 20", "20 / 20", "18 / 20"]
				var details := ["66.0 秒 / 目标 60 秒", "11 辆 / 目标 12 辆", "0 次 / 每次扣 4 分", "54 枚 / 目标 60 枚"]
				for cell in range(4):
					var px := x + 24 + (cell % 2) * 194
					var py := 331.0 + (cell / 2) * 152
					panel(Rect2(px, py, 182, 138), Color("162c3e"))
					label_at(px + 14, py + 31, names[cell], 20, muted)
					label_at(px + 14, py + 77, scores[cell], 30, cyan)
					label_at(px + 14, py + 113, details[cell], 13)
				label_at(x + 26, 676, "比赛得分  007200  ·  银牌奖励保留", 16, muted)
			else:
				label_at(x + 28, 254, "驾驶评级  S", 35, gold)
				label_at(x + 28, 308, "总分 92 / 100", 29)
				label_at(x + 28, 352, "项目           本局           得分", 19, muted)
				var rows := ["用时          66.0 秒       36 / 40", "超车          11 辆          18 / 20", "碰撞          0 次            20 / 20", "金币          54 枚          18 / 20"]
				for row in range(4):
					var py := 389.0 + row * 51
					draw_line(Vector2(x + 26, py - 19), Vector2(x + 398, py - 19), Color("254359"))
					label_at(x + 28, py + 12, rows[row], 19)
				panel(Rect2(x + 24, 597, 376, 88), Color("162c3e"))
				label_at(x + 39, 629, "本赛道最佳   S · 92 分", 20, gold)
				label_at(x + 39, 663, "保持零碰撞，尝试缩短用时。", 17, muted)
		label_at(42, 873, "方向键 / Enter / Esc 全键盘操作 · 正式版本将适配 720p、1080p、中英文与高对比模式", 16, muted)

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i.ZERO
	var preview := Preview.new()
	root.add_child(preview)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/previews/rating-layouts.png")
	print("Rating layout preview: ", error_string(error))
	quit(0 if error == OK else 1)
