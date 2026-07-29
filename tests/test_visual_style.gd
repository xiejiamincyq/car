extends SceneTree

const VisualStyle = preload("res://scripts/visual_style.gd")

func _init() -> void:
	assert(VisualStyle.hud_scale_for_width(1280.0) == 1.0, "1080p layouts must retain the base HUD scale")
	assert(VisualStyle.hud_scale_for_width(854.0) >= 0.78, "720p layouts must retain readable HUD text")
	assert(VisualStyle.is_high_contrast(VisualStyle.PLAYER_BODY, VisualStyle.ROAD), "The player car must separate from the road")
	assert(VisualStyle.is_high_contrast(VisualStyle.FUEL_GLOW, VisualStyle.ROAD), "Fuel pickups must separate from the road")
	assert(VisualStyle.is_high_contrast(VisualStyle.EDGE_NEON, VisualStyle.ROAD), "Road edges must remain readable")
	quit()
