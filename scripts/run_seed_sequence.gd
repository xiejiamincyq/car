class_name RunSeedSequence
extends RefCounted

var _random := RandomNumberGenerator.new()

func _init(sequence_seed: int) -> void:
	_random.seed = sequence_seed

func next_seed() -> int:
	return int(_random.randi())
