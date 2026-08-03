class_name TrackGeometry
extends RefCounted

const PLAYER_BOTTOM_MARGIN := 128.0
const FAST_OVERTAKE_STAGING_OFFSET := 108.0
const FAST_OVERTAKE_SPAWN_OFFSET := 380.0
const NORMAL_RECYCLE_OFFSET := 140.0
const FAST_RECYCLE_Y := -100.0

static func player_y(viewport_height: float) -> float:
	return maxf(PLAYER_BOTTOM_MARGIN, viewport_height) - PLAYER_BOTTOM_MARGIN

static func fast_overtake_staging_y(viewport_height: float) -> float:
	return player_y(viewport_height) + FAST_OVERTAKE_STAGING_OFFSET

static func fast_overtake_spawn_y(viewport_height: float) -> float:
	return maxf(PLAYER_BOTTOM_MARGIN, viewport_height) + FAST_OVERTAKE_SPAWN_OFFSET

static func normal_recycle_y(viewport_height: float) -> float:
	return maxf(PLAYER_BOTTOM_MARGIN, viewport_height) + NORMAL_RECYCLE_OFFSET
