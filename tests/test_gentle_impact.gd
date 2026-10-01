extends SceneTree
const Impact = preload("res://scripts/impact_model.gd")

func _init() -> void:
	assert(Impact.resolve(Vector2(0,-230), Vector2(0,-200), Vector2.UP).damage <= 2.0, "A low closing-speed bump must not consume a large part of the hull")
	assert(Impact.resolve(Vector2(200,-300), Vector2(0,-200), Vector2.RIGHT).damage <= 6.0, "A steering sideswipe must be gentle despite the large steering velocity")
	assert(Impact.resolve(Vector2(0,-400), Vector2(0,-200), Vector2.UP).damage >= 40.0, "High-speed frontal crashes must remain dangerous")
	assert(Impact.resolve(Vector2(0,-200), Vector2(0,-200), Vector2.UP).damage == 0.0)
	quit()
