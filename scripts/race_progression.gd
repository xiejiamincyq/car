class_name RaceProgression
extends RefCounted

var checkpoint_distances: Array[float] = []
var finish_distance: float
var stage: int = 0
var _next_checkpoint_index: int = 0
var _clear_emitted := false

func _init(checkpoints: Array, finish: float) -> void:
	for checkpoint in checkpoints:
		checkpoint_distances.append(maxf(0.0, float(checkpoint)))
	checkpoint_distances.sort()
	finish_distance = maxf(checkpoint_distances.back() if not checkpoint_distances.is_empty() else 0.0, finish)

func observe(distance: float) -> Dictionary:
	var checkpoints_crossed := 0
	while _next_checkpoint_index < checkpoint_distances.size() and distance >= checkpoint_distances[_next_checkpoint_index]:
		_next_checkpoint_index += 1
		checkpoints_crossed += 1
	stage = mini(_next_checkpoint_index, checkpoint_distances.size())
	var cleared := false
	if not _clear_emitted and distance >= finish_distance:
		_clear_emitted = true
		cleared = true
	return {"stage": stage, "checkpoints_crossed": checkpoints_crossed, "cleared": cleared}

func reset() -> void:
	stage = 0
	_next_checkpoint_index = 0
	_clear_emitted = false
