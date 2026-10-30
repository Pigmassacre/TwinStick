class_name Balance
## Every number worth tuning, in one place.

# --- the ranger ---------------------------------------------------------------
const MOVE_SPEED := 104.0
const DEMOLITION_MOVE := 0.82
const RADIUS := 5.0
const START_WICKS := 5
const INVULNERABLE_AFTER_HIT := 1.25
## A hit flares the lamp: what's this close is thrown back from it, and stunned a moment.
const HIT_SHOVE_REACH := 36.0
const HIT_SHOVE := 190.0
const HIT_STUN := 0.45
const ROLL_SPEED := 260.0
const ROLL_TIME := 0.24
const ROLL_COOLDOWN := 1.0
## The original game's stick needed pushing past this before an arrow flew.
const AIM_DEADZONE := 0.25

# --- arrows -------------------------------------------------------------------
const ARROW_SPEED := 340.0
const ARROW_DAMAGE := 2.0
const ARROW_COOLDOWN := 0.17
const ARROW_LIFE := 0.9
const ARROW_HEIGHT := 7.0
const ARROW_SPREAD := 0.03
const TWIN_FAN := 0.13

# --- demolition ---------------------------------------------------------------
const CHARGE_SPEED := 230.0
const CHARGE_COOLDOWN := 0.62
const CHARGE_LIFE := 1.2
const BLAST_RADIUS := 34.0
const BLAST_DAMAGE := 9.0
const START_POWDER := 5
const MAX_POWDER := 8
## A pinch of powder comes back by itself, so nobody is ever walled in for good.
const POWDER_REGEN := 16.0
const WALL_BREAK_RADIUS := 26.0

# --- the lamp -----------------------------------------------------------------
## How far the lamp shines (world units) with all wicks lit, and with the last one.
const LAMP_RANGE_FULL := 215.0
const LAMP_RANGE_LAST := 130.0
const LAMP_ENERGY := 0.62
const LAMP_HEIGHT := 22.0
## Within this much of the lamp's reach (in pixels of floor), what sleeps in the dark wakes.
const WAKE_DISTANCE := 118.0

# --- the mine -----------------------------------------------------------------
const FLOW_INTERVAL := 0.2
const BUDGET_BASE := 13.0
const BUDGET_PER_LEVEL := 5.2
## Once this share of a level is dead, the second shift comes in, this big.
const SECOND_SHIFT_AT := 0.6
const SECOND_SHIFT_SIZE := 0.45
## Past this long, the ones still asleep come hunting.
const RESTLESS_AFTER := 70.0

# --- score --------------------------------------------------------------------
const STREAK_TIME := 2.6
const STREAK_MAX := 8
const NUGGET_SCORE := 25
const STAGE_BONUS := 250
const POWDER_DROP := 0.1
const OIL_DROP := 0.022
const NUGGET_DROP := 0.5

# --- the hard shift (unlocked by getting out alive) --------------------------------
const HARD_ENEMY_HP := 1.45
const HARD_ENEMY_SPEED := 1.14
const HARD_BUDGET := 1.35
