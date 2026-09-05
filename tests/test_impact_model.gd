extends SceneTree
const Impact = preload("res://scripts/impact_model.gd")
func _init() -> void:
	assert(Impact.base_damage(3.0) == 0.0)
	assert(Impact.base_damage(60.0) == 11.0)
	var hit := Impact.resolve(Vector2(0,-250), Vector2(0,-200), Vector2.UP)
	assert(hit.closing == 50.0 and hit.damage < 11.0)
	assert(Impact.resolve(Vector2(0,-250), Vector2(0,-250), Vector2.RIGHT).damage == 0.0)
	assert(Impact.resolve(Vector2.ZERO, Vector2(0,-100), Vector2.DOWN).damage > 0.0)
	assert(Impact.resolve(Vector2(0,-100), Vector2.ZERO, Vector2.UP, 1, 2.5).damage > Impact.resolve(Vector2(0,-100), Vector2.ZERO, Vector2.UP).damage)
	assert(Impact.resolve(Vector2(0,-300), Vector2.ZERO, Vector2.UP, 1, 0.01, 1, false, true).damage <= 2.0)
	assert(Impact.resolve(Vector2(0,-100), Vector2(0,-200), Vector2.UP).damage == 0.0)
	quit()
