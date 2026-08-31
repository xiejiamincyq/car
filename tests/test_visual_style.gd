extends SceneTree

const VisualStyle = preload("res://scripts/visual_style.gd")

func _init() -> void:
	assert(VisualStyle.hud_scale_for_width(1920.0) == 1.0, "1920x1080 layouts must retain the base HUD scale")
	assert(VisualStyle.hud_scale_for_width(1280.0) == 1.0, "1280x720 layouts must retain the base HUD scale")
	assert(VisualStyle.hud_height_for_scale(VisualStyle.hud_scale_for_width(1920.0)) <= 146.0, "1080p HUD must fit within its 146px panel")
	assert(VisualStyle.hud_height_for_scale(VisualStyle.hud_scale_for_width(1280.0)) <= 146.0, "720p HUD must fit within its 146px panel")
	assert(VisualStyle.is_high_contrast(VisualStyle.PLAYER_BODY, VisualStyle.ROAD), "The player car must separate from the road")
	assert(VisualStyle.is_high_contrast(VisualStyle.FUEL_GLOW, VisualStyle.ROAD), "Fuel pickups must separate from the road")
	assert(VisualStyle.is_high_contrast(VisualStyle.EDGE_NEON, VisualStyle.ROAD), "Road edges must remain readable")
	assert(VisualStyle.is_high_contrast(VisualStyle.HIGH_CONTRAST_PLAYER, VisualStyle.HIGH_CONTRAST_ROAD), "The accessible player palette must retain high contrast")
	var traffic_colors := {}
	for kind in range(4):
		traffic_colors[VisualStyle.traffic_color(kind, true)] = true
	assert(traffic_colors.size() == 4, "NPC silhouettes must remain distinguishable in high-contrast mode after body markers are removed")
	quit()
