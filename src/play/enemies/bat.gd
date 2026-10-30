extends Enemy
## Hangs asleep until the light is on it. Then dives at you in straight lines, and thinks about it.

var dive := Vector2.ZERO


func init() -> void:
	height = 13.0
	state = 0
	timer = randf_range(0.2, 0.9)
	anim = "idle"


func on_wake() -> void:
	anim = "fly"
	Audio.play("bat", -8.0, randf_range(0.9, 1.3))


func think(dt: float) -> void:
	timer -= dt
	if state == 0:
		# Hovering about, getting ready.
		go(Vector2.from_angle(anim_time * 3.0), dt, 0.25)
		if timer <= 0.0:
			state = 1
			timer = 0.65
			dive = dir_to_player()
			facing = sign(dive.x) if dive.x != 0.0 else facing
	else:
		go(dive, dt)
		if timer <= 0.0:
			state = 0
			timer = randf_range(0.5, 1.0)
