extends Enemy
## Rats keep coming out of it until somebody does something about it.

const EVERY := 3.2
const MAX_OUT := 6

var out: Array = []


func init() -> void:
	timer = EVERY * 0.5
	anim = "idle"


func think(dt: float) -> void:
	timer -= dt
	if timer <= 0.0:
		timer = EVERY
		out = out.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.alive)
		if out.size() < MAX_OUT:
			var rat: Enemy = world.spawn_enemy("rat", pos + Vector2(randf_range(-6, 6), 8.0))
			rat.wake()
			rat.counted = false
			out.append(rat)
			world.fx.chips(pos, 5.0, 3, Color("8a5c36"), 40.0, 1.0)


func _contact() -> void:
	pass
