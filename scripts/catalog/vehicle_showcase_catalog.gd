extends RefCounted
## Exhibition portraits are deliberately separate from racing sprites.
const TEXTURES := {
	&"pulse_gt": preload("res://assets/vehicle_showcases/pulse_gt_northwest_v1.png"),
	&"driftwing": preload("res://assets/vehicle_showcases/driftwing_northwest_v1.png"),
	&"flashpoint": preload("res://assets/vehicle_showcases/flashpoint_northwest_v1.png"),
	&"comet_rs": preload("res://assets/vehicle_showcases/comet_rs_northwest_v1.png"),
	&"tidebreaker": preload("res://assets/vehicle_showcases/tidebreaker_northwest_v1.png"),
	&"aurora_x": preload("res://assets/vehicle_showcases/aurora_x_northwest_v1.png"),
}
static func texture_for(vehicle_id: StringName) -> Texture2D:
	return TEXTURES.get(vehicle_id)
