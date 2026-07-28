extends SceneTree

const Main = preload("res://scripts/main.gd")

func _init() -> void:
	var next_offset = Main.advance_road_scroll(10.0, 100.0, 1.0, 200.0)
	assert(is_equal_approx(next_offset, 125.0), "Forward motion must advance road markings down the screen")

	var repeat_distance = Main.ROAD_MARK_REPEAT_DISTANCE
	var before_wrap_start = Main.get_dash_start_y(repeat_distance - 1.0, repeat_distance)
	var after_wrap_start = Main.get_dash_start_y(1.0, repeat_distance)
	assert(is_equal_approx(before_wrap_start + 2.0, after_wrap_start + repeat_distance), "The visible marker must continue through scroll wrap")
	assert(is_equal_approx(after_wrap_start, 1.0 - repeat_distance), "Drawing must begin with the prior marker above the screen")
	quit()
