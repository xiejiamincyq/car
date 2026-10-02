extends SceneTree
const Traffic = preload("res://scripts/traffic_director.gd")
class ProfiledTraffic extends Traffic:
	var wall_usec := 0
	var following_usec := 0
	var calls := 0
	func _wall_following_target(vehicle) -> float:
		var started := Time.get_ticks_usec()
		var result := super._wall_following_target(vehicle)
		wall_usec += Time.get_ticks_usec() - started
		return result
	func _following_target_speed(vehicle) -> float:
		var started := Time.get_ticks_usec()
		var result := super._following_target_speed(vehicle)
		following_usec += Time.get_ticks_usec() - started
		calls += 1
		return result
func _init() -> void:
	var traffic := ProfiledTraffic.new(13)
	traffic.set_difficulty_stage(3)
	var started := Time.get_ticks_usec()
	for step in range(600):
		traffic.tick(0.1, (0.5 + 0.5 * sin(float(step) * 0.035)) * 980.0, (13 + step / 90) % 3)
	print("TRAFFIC_PROFILE ", JSON.stringify({"total_usec":Time.get_ticks_usec()-started,"following_usec":traffic.following_usec,"wall_usec":traffic.wall_usec,"calls":traffic.calls,"scope":"headless model CPU measurement, not graphical FPS"}))
	print("TEST_COMPLETE test_product_traffic_profile.gd")
	quit(0)
