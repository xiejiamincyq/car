class_name GameConfig
extends RefCounted

# Keep first-playable balance values together so playtest feedback can change
# the driving feel without scattering numbers across scene scripts.
const ROAD_LANE_COUNT: int = 3
const ROAD_HALF_WIDTH: float = 390.0

const START_SPEED: float = 280.0
const MAX_SPEED: float = 760.0
const ACCELERATION: float = 220.0
const BRAKING: float = 420.0
const STEERING_SPEED: float = 540.0
const ROAD_SCROLL_MULTIPLIER: float = 1.15

const MIN_SPAWN_DISTANCE: float = 620.0
const MIN_TRAFFIC_GAP: float = 180.0
const COLLISION_INVULNERABILITY_SECONDS: float = 1.0

const FUEL_DRAIN_PER_SECOND: float = 4.0
const FUEL_PICKUP_AMOUNT: float = 28.0
