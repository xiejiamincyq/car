extends SceneTree

const TrackGeometry = preload("res://scripts/track_geometry.gd")
const TrafficDirector = preload("res://scripts/traffic_director.gd")

func _init() -> void:
	for viewport_height in [720.0, 1080.0]:
		var player_y := TrackGeometry.player_y(viewport_height)
		var fast_staging_y := TrackGeometry.fast_overtake_staging_y(viewport_height)
		var normal_recycle_y := TrackGeometry.normal_recycle_y(viewport_height)
		assert(fast_staging_y > player_y + 72.0, "Rear overtakers must stage behind the player's collision box")
		assert(fast_staging_y < viewport_height, "Rear-overtake warnings must remain visible")
		assert(normal_recycle_y > player_y + 72.0, "Normal traffic must cross the player before recycling")

		var director := TrafficDirector.new(101)
		director.set_viewport_height(viewport_height)
		var normal_vehicle = director.acquire_vehicle(TrafficDirector.Kind.STEADY_SLOW, 1, player_y - 90.0)
		director.update_vehicle(normal_vehicle, 1.0, 500.0)
		assert(normal_vehicle.y > player_y, "Normal traffic must be able to pass the player at every supported height")

		var rear_vehicle = director.acquire_vehicle(TrafficDirector.Kind.FAST_OVERTAKE, 1, viewport_height + 100.0)
		director.update_vehicle(rear_vehicle, 1.0, 760.0)
		assert(is_equal_approx(rear_vehicle.y, fast_staging_y), "Rear traffic must stage relative to the player line")
		assert(rear_vehicle.overtake_warning_remaining >= 1.0, "Rear traffic must warn before overtaking")
	quit()
