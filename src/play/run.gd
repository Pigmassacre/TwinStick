class_name Run
extends RefCounted
## One shift down the mine: what the ranger is carrying, and how far it has gone.

enum { NORMAL, HARD, DAILY }

var mode := NORMAL
var seed_value := 0
var rng := RandomNumberGenerator.new()
var levels: Array = []
var level_index := 0
var wicks := Balance.START_WICKS
var max_wicks := Balance.START_WICKS
var powder := Balance.START_POWDER
var perks := {}
var score := 0
var kills := 0
var nuggets := 0
var time := 0.0
var best_streak := 1
var hits_taken := 0
var walls_blown := 0
## Second Wind: used in this depth.
var second_wind_used := false
## The things already explained once: id -> true.
var hints := {}


func start(the_mode: int, the_seed: int, first_level := 0) -> void:
	mode = the_mode
	seed_value = the_seed
	rng.seed = the_seed
	levels = Depths.levels()
	level_index = clampi(first_level, 0, levels.size() - 1)


func level() -> Dictionary:
	return levels[level_index]


func depth() -> Dictionary:
	return Depths.LIST[level().depth]


func is_last_level() -> bool:
	return level_index >= levels.size() - 1


## Moves on to the next level. A new depth gives the Second Wind back.
func advance() -> void:
	var old_depth: int = level().depth
	level_index = mini(level_index + 1, levels.size() - 1)
	if level().depth != old_depth:
		second_wind_used = false


func has(perk: String) -> bool:
	return perks.has(perk)


func count(perk: String) -> int:
	return int(perks.get(perk, 0))


func add_perk(perk: String) -> void:
	perks[perk] = count(perk) + 1
	match perk:
		"wick":
			max_wicks += 1
			wicks += 1
		"keg":
			powder = mini(powder + 3, max_powder())


func max_powder() -> int:
	return Balance.MAX_POWDER + count("keg") * 3


func arrow_cooldown() -> float:
	return Balance.ARROW_COOLDOWN * pow(0.8, count("quick"))


func arrow_damage() -> float:
	return Balance.ARROW_DAMAGE * pow(1.5, count("heavy"))


func blast_radius() -> float:
	return Balance.BLAST_RADIUS * (1.0 + 0.28 * count("blast"))


func blast_damage() -> float:
	return Balance.BLAST_DAMAGE * (1.0 + 0.4 * count("blast"))


func roll_cooldown() -> float:
	return Balance.ROLL_COOLDOWN * pow(0.67, count("roll"))


func lamp_scale() -> float:
	return 1.0 + 0.22 * count("wide")


func enemy_hp_scale() -> float:
	var scale := 1.0 + 0.045 * level_index
	if mode == HARD:
		scale *= Balance.HARD_ENEMY_HP
	return scale


func enemy_speed_scale() -> float:
	return Balance.HARD_ENEMY_SPEED if mode == HARD else 1.0


func budget() -> float:
	var b := Balance.BUDGET_BASE + Balance.BUDGET_PER_LEVEL * level_index
	return b * (Balance.HARD_BUDGET if mode == HARD else 1.0)
