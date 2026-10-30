extends Enemy
## What's left of the night shift: slow, hard to put down, and when it's close it swings.

const WINDUP := 0.45


func init() -> void:
	anim = "walk"


func think(dt: float) -> void:
	match state:
		0:
			anim = "walk"
			walk_to_player(dt)
			if to_player().length() < 30.0 and sees_player():
				state = 1
				timer = WINDUP
				anim = "swing"
				vel = Vector2.ZERO
				Audio.play("miner_grunt", -8.0, randf_range(0.85, 1.05))
		1:
			face_player()
			timer -= dt
			sprite.set_flash(Color(1.0, 0.3, 0.2), 0.45 if int(timer * 16.0) % 2 == 0 else 0.0)
			if timer <= 0.0:
				sprite.set_flash(Color.WHITE, 0.0)
				state = 2
				timer = 0.18
				knock = dir_to_player() * 230.0
				Audio.play("swing", -6.0, randf_range(0.9, 1.1))
		2:
			timer -= dt
			if timer <= 0.0:
				state = 3
				timer = 0.7
				anim = "idle"
				world.fx.sparks(pos + Vector2(facing * 9.0, 0.0), 6.0, 5, Color(1.0, 0.8, 0.4), 80.0, 0.2)
		3:
			timer -= dt
			if timer <= 0.0:
				state = 0
