extends SceneTree

const CollisionSound = preload("res://scripts/collision_sound.gd")

func _init() -> void:
	var stream := CollisionSound.create_stream()
	assert(stream is AudioStreamWAV, "Collision placeholder must be a playable Godot audio stream")
	assert(stream.data.size() > 0, "Collision placeholder must contain generated samples")
	quit()
