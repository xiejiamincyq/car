class_name VisualStyle
extends RefCounted

# Original neon-coast palette. Keep gameplay colours centralized so readability
# changes never alter traffic, fuel, or collision rules.
const OCEAN := Color("081725")
const SHOULDER := Color("123a46")
const ROAD := Color("182332")
const STAGE_ROAD_COLORS := [Color("182332"), Color("1d2938"), Color("24273d"), Color("2b243d")]
const EDGE_NEON := Color("45e6e0")
const LANE_MARK := Color("d8f7f4")
const PLAYER_BODY := Color("39b9ff")
const PLAYER_GLOW := Color("b8f7ff")
const SLOW_BODY := Color("ff795e")
const SIGNAL_BODY := Color("ffc84f")
const FAST_BODY := Color("e96cff")
const TRUCK_BODY := Color("8f95a8")
const FUEL_GLOW := Color("66f5a0")
const HUD_TEXT := Color("e7fbff")
const HUD_DIM := Color("9fc9d4")
const WARNING := Color("ffeb65")

# Okabe-Ito-inspired colours on a near-black road for players who need stronger
# luminance separation or cannot reliably distinguish the default neon hues.
const HIGH_CONTRAST_ROAD := Color("05070a")
const HIGH_CONTRAST_OCEAN := Color("000000")
const HIGH_CONTRAST_SHOULDER := Color("202830")
const HIGH_CONTRAST_PLAYER := Color("f0e442")
const HIGH_CONTRAST_PLAYER_GLOW := Color("ffffff")
const HIGH_CONTRAST_TRAFFIC := [Color("e69f00"), Color("56b4e9"), Color("cc79a7"), Color("f2f2f2")]
const HIGH_CONTRAST_FUEL := Color("00d98b")
const HIGH_CONTRAST_EDGE := Color("ffffff")
const HIGH_CONTRAST_LANE := Color("ffffff")
const HIGH_CONTRAST_WARNING := Color("ffffff")

static func hud_scale_for_width(viewport_width: float) -> float:
	return clampf(viewport_width / 1280.0, 0.78, 1.0)

static func hud_height_for_scale(_scale: float) -> float:
	# Godot containers reserve the unscaled label minimum sizes: 98px labels,
	# 12px row gaps, and 24px panel margins = 134px inside a 146px HUD panel.
	return 134.0

static func is_high_contrast(foreground: Color, background: Color) -> bool:
	var brighter := maxf(_luminance(foreground), _luminance(background)) + 0.05
	var darker := minf(_luminance(foreground), _luminance(background)) + 0.05
	return brighter / darker >= 2.4

static func road_color_for_transition(previous_stage: int, current_stage: int, mix_amount: float, high_contrast := false) -> Color:
	if high_contrast:
		return HIGH_CONTRAST_ROAD
	var from_color: Color = STAGE_ROAD_COLORS[clampi(previous_stage, 0, STAGE_ROAD_COLORS.size() - 1)]
	var to_color: Color = STAGE_ROAD_COLORS[clampi(current_stage, 0, STAGE_ROAD_COLORS.size() - 1)]
	return from_color.lerp(to_color, clampf(mix_amount, 0.0, 1.0))

static func traffic_color(kind: int, high_contrast: bool) -> Color:
	if high_contrast:
		return HIGH_CONTRAST_TRAFFIC[clampi(kind, 0, HIGH_CONTRAST_TRAFFIC.size() - 1)]
	return [SLOW_BODY, SIGNAL_BODY, FAST_BODY, TRUCK_BODY][clampi(kind, 0, 3)]

static func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
