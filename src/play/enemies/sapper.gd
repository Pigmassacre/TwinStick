extends Enemy
## Runs at you with the fuse already lit. Shoot it among its friends.

const FUSE := 0.7

var lit := false
var blown := false


func init() -> void:
	anim = "idle"


func think(dt: float) -> void:
	if not lit:
		walk_to_player(dt)
		if randf() < dt * 8.0:
			world.fx.sparks(pos + Vector2(facing * 1.0, 0.0), 15.0, 1, Color(1.0, 0.75, 0.3), 20.0, 0.25)
		if to_player().length() < 26.0:
			lit = true
			timer = FUSE
			Audio.play("fuse", -2.0)
	else:
		timer -= dt
		go(dir_to_player(), dt, 0.4)
		sprite.set_flash(Color(1.0, 0.95, 0.5), 0.8 if int(timer * 22.0) % 2 == 0 else 0.0)
		if timer <= 0.0:
			die("blast")


func die(kind := "arrow") -> void:
	if blown:
		return
	blown = true
	var was_alive := alive
	super.die(kind)
	if was_alive:
		world.explode(pos, 36.0, 10.0, false, false)
