class_name EnvironmentScroller
extends RefCounted

static func tile_positions(scroll: float, viewport_height: float, tile_height: float) -> PackedFloat32Array:
	var positions := PackedFloat32Array()
	if viewport_height <= 0.0 or tile_height <= 0.0:
		return positions
	var first_y := fposmod(scroll, tile_height) - tile_height
	var y := first_y
	while y < viewport_height:
		positions.append(y)
		y += tile_height
	return positions
