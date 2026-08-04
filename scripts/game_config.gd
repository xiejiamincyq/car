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
const COLLISION_SPEED_PENALTY: float = 260.0
const COLLISION_LATERAL_DISTANCE: float = 50.0
const COLLISION_LONGITUDINAL_DISTANCE: float = 72.0
const NEAR_MISS_LATERAL_DISTANCE: float = 88.0
const PASS_SETTLEMENT_DISTANCE: float = 76.0
const TRAFFIC_RANDOM_SEED: int = 20260728
const TRAFFIC_SPAWN_INTERVAL: float = 0.85

const FUEL_DRAIN_PER_SECOND: float = 4.0
const FUEL_PICKUP_AMOUNT: float = 24.0
const MAX_FUEL: float = 100.0
const FUEL_GRACE_SECONDS: float = 30.0
const FUEL_PICKUP_INTERVAL: float = 8.0
const FUEL_SPAWN_SAFETY_DISTANCE: float = 240.0
const OVERTAKE_SCORE: int = 80
const NEAR_MISS_SCORE: int = 120
const COMBO_WINDOW_SECONDS: float = 2.5
const COMBO_MAX_MULTIPLIER: int = 3
const COMBO_EVENTS_PER_MULTIPLIER: int = 4
const SPARK_MAX_COUNT: int = 24
