class_name EnvironmentScroller
extends RefCounted

static func segment_distances(finish_distance: float, transition_count: int) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	if finish_distance <= 0.0 or transition_count <= 0:
		return distances
	var distance_per_transition := finish_distance / float(transition_count)
	for transition_index in range(transition_count):
		distances.append(distance_per_transition)
	var accumulated := 0.0
	for distance in distances:
		accumulated += distance
	distances[-1] += finish_distance - accumulated
	return distances

static func sequence_tiles(race_distance: float, finish_distance: float, viewport_height: float, tile_height: float, texture_count: int) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	if finish_distance <= 0.0 or viewport_height <= 0.0 or tile_height <= 0.0 or texture_count <= 0:
		return tiles
	var transition_count := maxi(0, texture_count - 1)
	var clamped_distance := clampf(race_distance, 0.0, finish_distance)
	var scroll := clamped_distance / finish_distance * float(transition_count) * tile_height
	var current_index := mini(floori(scroll / tile_height), texture_count - 1)
	var current_y := scroll - float(current_index) * tile_height
	for texture_index in range(current_index, texture_count):
		var tile_y := current_y - float(texture_index - current_index) * tile_height
		if tile_y >= viewport_height:
			continue
		if tile_y + tile_height <= 0.0:
			break
		tiles.append({"index": texture_index, "y": tile_y})
	return tiles
