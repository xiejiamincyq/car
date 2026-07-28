extends SceneTree

const CollisionResponder = preload("res://scripts/collision_responder.gd")

func _init() -> void:
	var responder = CollisionResponder.new(300.0, 1.0)
	var first_hit = responder.try_collide(600.0)
	assert(first_hit.hit, "The first collision must be accepted")
	assert(is_equal_approx(first_hit.speed, 300.0), "A collision must apply its speed penalty")
	assert(not responder.try_collide(first_hit.speed).hit, "Invulnerability must prevent duplicate penalties")
	responder.advance(1.0)
	assert(responder.try_collide(600.0).hit, "Collision must become possible after invulnerability")
	quit()
