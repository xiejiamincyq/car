class_name VisualStyle
extends RefCounted

# Original neon-coast palette. Keep gameplay colours centralized so readability
# changes never alter traffic, fuel, or collision rules.
const OCEAN := Color("081725")
const SHOULDER := Color("123a46")
const ROAD := Color("182332")
const EDGE_NEON := Color("45e6e0")
const LANE_MARK := Color("d8f7f4")
const PLAYER_BODY := Color("39b9ff")
const PLAYER_GLOW := Color("b8f7ff")
const SLOW_BODY := Color("ff795e")
const SIGNAL_BODY := Color("ffc84f")
const FAST_BODY := Color("e96cff")
const FUEL_GLOW := Color("66f5a0")
const HUD_TEXT := Color("e7fbff")
const HUD_DIM := Color("9fc9d4")
const WARNING := Color("ffeb65")

static func hud_scale_for_width(viewport_width: float) -> float:
	return clampf(viewport_width / 1280.0, 0.78, 1.0)

static func is_high_contrast(foreground: Color, background: Color) -> bool:
	var brighter := maxf(_luminance(foreground), _luminance(background)) + 0.05
	var darker := minf(_luminance(foreground), _luminance(background)) + 0.05
	return brighter / darker >= 2.4

static func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
