extends SceneTree

const Main = preload("res://scripts/main.gd")

func _init() -> void:
	var next_offset = Main.advance_road_scroll(10.0, 100.0, 1.0, 200.0)
	assert(is_equal_approx(next_offset, 125.0), "Forward motion must advance road markings down the screen")
	quit()
