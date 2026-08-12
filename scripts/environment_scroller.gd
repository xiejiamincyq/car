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

static func variant_index(tile_index: int, seed: int, variant_count: int) -> int:
	if variant_count <= 1:
		return 0
	var mixed := tile_index * 1103515245 + seed * 12345 + 0x45D9F3B
	return posmod(mixed ^ (mixed >> 16), variant_count)
