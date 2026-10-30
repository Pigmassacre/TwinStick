extends Enemy
## Still on shift. Throws nails in threes, and has only to blow the whistle for
## everything in earshot to wake up.

const THROW_EVERY := 1.9


func init() -> void:
	timer = 1.0
	anim = "idle"


func on_wake() -> void:
	Audio.play("whistle", -6.0)
	world.say_at(pos, "Whistle!", Color("ffe27a"))
	world.wake_near(pos, 150.0)


func think(dt: float) -> void:
	keep_range(dt, 70.0, 150.0)
	face_player()
	timer -= dt
	if timer <= 0.0:
		timer = THROW_EVERY + randf_range(-0.2, 0.4)
		if sees_player():
			world.shots.fan(pos, dir_to_player(), 3, 0.5, 118.0, Shots.NAIL)
			Audio.play("throw", -7.0, randf_range(0.9, 1.1))
