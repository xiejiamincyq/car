class_name ImpactModel
extends RefCounted

const SPEEDS := [3.0, 10.0, 30.0, 60.0, 100.0, 150.0, 200.0]
const DAMAGE := [0.0, 1.0, 4.0, 11.0, 23.0, 40.0, 60.0]

static func base_damage(kmh: float) -> float:
	if kmh <= SPEEDS[0]:
		return 0.0
	for index in range(1, SPEEDS.size()):
		if kmh <= SPEEDS[index]:
			return lerpf(DAMAGE[index-1], DAMAGE[index], (kmh-SPEEDS[index-1])/(SPEEDS[index]-SPEEDS[index-1]))
	return 60.0

# Velocities use km/h and screen axes: forward is negative Y. Normal points
# from the player towards the other body. Only approaching motion is an impact.
static func resolve(player_velocity: Vector2, other_velocity: Vector2, normal: Vector2, player_mass: float = 1.0, other_mass: float = 1.0, protection: float = 1.0, fixed: bool = false, cone: bool = false) -> Dictionary:
	var n := normal.normalized()
	var closing := maxf(0.0, (player_velocity-other_velocity).dot(n))
	var share := 1.0 if fixed else other_mass / maxf(0.01, player_mass+other_mass)
	var mass_factor := clampf(share * 2.0, 0.7, 1.4)
	var location_factor := 1.15 if absf(n.x) > 0.5 else (0.85 if n.y > 0.0 else 1.0)
	var damage := base_damage(closing) * mass_factor * location_factor / clampf(protection, 0.85, 1.15)
	if cone:
		damage = minf(2.0, base_damage(closing) * 0.035)
	var impulse := closing * share * (0.08 if cone else 0.9)
	return {"damage": damage, "closing": closing, "player_delta": -n * impulse, "other_delta": n * closing * (1.0-share) * 0.9 if not fixed else Vector2.ZERO}

static func contact_normal(offset: Vector2, extents: Vector2) -> Vector2:
	if absf(offset.x) / maxf(1.0, extents.x) > absf(offset.y) / maxf(1.0, extents.y):
		return Vector2(1.0 if offset.x >= 0.0 else -1.0, 0.0)
	return Vector2(0.0, 1.0 if offset.y > 0.0 else -1.0)
