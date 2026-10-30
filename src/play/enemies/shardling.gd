extends Enemy
## Grown out of the crystal. Arrows glance straight off it: a blast is what it
## takes. It lets go a slow, turning cross of shards.

const FIRE_EVERY := 1.15

var turn := 0.0


func init() -> void:
	timer = randf_range(0.5, FIRE_EVERY)
	anim = "idle"


func think(dt: float) -> void:
	keep_range(dt, 60.0, 140.0)
	face_player()
	timer -= dt
	if timer <= 0.0:
		timer = FIRE_EVERY
		turn += 0.42
		if to_player().length() < 230.0:
			world.shots.ring(pos, 4, 66.0, Shots.SHARD, turn)
			Audio.play("shard", -12.0, randf_range(1.0, 1.3))


func die(kind := "arrow") -> void:
	if alive and world:
		world.shots.ring(pos, 6, 90.0, Shots.SHARD, randf() * TAU)
		world.fx.chips(pos, 6.0, 14, Color("9ff0d8"), 110.0, 1.6)
		Audio.play("shatter", -3.0)
	super.die(kind)
