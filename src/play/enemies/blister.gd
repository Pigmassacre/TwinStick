extends Enemy
## A swollen thing that spits firedamp. The gas does nothing by itself, of course.

const SPIT_EVERY := 2.8


func init() -> void:
	timer = randf_range(0.8, SPIT_EVERY)
	anim = "breathe"


func think(dt: float) -> void:
	timer -= dt
	face_player()
	keep_range(dt, 80.0, 180.0, 1.0)
	if timer < 0.5 and sees_player():
		anim = "spit"
	if timer <= 0.0:
		anim = "breathe"
		timer = SPIT_EVERY + randf_range(-0.3, 0.5)
		if sees_player() and to_player().length() < 240.0:
			world.shots.lob(pos, world.player.pos + world.player.vel * 0.5, 0.9, Shots.SPIT, "gas")
			Audio.play("spit", -5.0, randf_range(0.9, 1.15))
			knock = -dir_to_player() * 30.0


func die(kind := "arrow") -> void:
	# It goes off like a wet bag of the stuff.
	if alive and world:
		world.gas.puff(pos, 0.9, 1)
		Audio.play("squelch", -3.0)
	super.die(kind)
