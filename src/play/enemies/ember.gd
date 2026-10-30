extends Enemy
## A hopping coal. Sets fire to where it lands, and it's nothing but fire when it dies.

var vh := 0.0
var hop := Vector2.ZERO


func init() -> void:
	timer = randf_range(0.2, 0.8)
	anim = "idle"
	set_meta("glowing", true)


func think(dt: float) -> void:
	if height > 0.0 or vh > 0.0:
		vh -= 420.0 * dt
		height += vh * dt
		go(hop, dt, 1.4)
		if height <= 0.0:
			height = 0.0
			vh = 0.0
			timer = randf_range(0.25, 0.6)
			world.gas.set_fire(Iso.cell_of(pos), 0.9)
			world.gas.ignite_near(pos, 10.0)
			Audio.play("ember", -14.0, randf_range(0.9, 1.3))
	else:
		timer -= dt
		if timer <= 0.0:
			vh = 110.0
			hop = dir_to_player().rotated(randf_range(-0.5, 0.5))


func die(kind := "arrow") -> void:
	if alive and world:
		var c := Iso.cell_of(pos)
		world.gas.set_fire(c, 2.0)
		world.gas.ignite_near(pos, 12.0)
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if randf() < 0.5:
				world.gas.set_fire(c + d, 1.4)
		world.fx.sparks(pos, 6.0, 8, Color(1.0, 0.6, 0.2), 90.0, 0.5)
	super.die(kind)
