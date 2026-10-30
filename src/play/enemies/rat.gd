extends Enemy
## Comes at you along the floor, fast, not quite in a straight line. Comes in numbers.

var scurry := randf() * TAU


func init() -> void:
	anim = "idle"


func think(dt: float) -> void:
	scurry += dt * 9.0
	var player: Player = world.player
	var dir: Vector2
	if world.map.line_clear(pos, player.pos):
		dir = dir_to_player()
	else:
		dir = world.map.flow_dir(pos)
	dir = dir.rotated(sin(scurry) * 0.6)
	go(dir, dt)
	if randf() < dt * 0.25:
		Audio.play("rat", -16.0, randf_range(0.9, 1.3))
