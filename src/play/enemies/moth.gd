extends Enemy
## Goes for the lamp, as moths do, weaving, right through the walls. If it gets
## there it goes up in a puff, and the lamp's dim for a while.

var weave := randf() * TAU


func init() -> void:
	height = 10.0
	anim = "idle"


func think(dt: float) -> void:
	weave += dt * 5.0
	var dir := dir_to_player()
	dir = dir.rotated(sin(weave) * 1.15)
	go(dir, dt)
	var player: Player = world.player
	if to_player().length() < 9.0 and player.can_be_hit():
		player.snuffed = maxf(player.snuffed, 3.5)
		world.fx.sparks(pos, height, 8, Color(1.0, 0.85, 0.5), 50.0, 0.3)
		Audio.play("snuff", -5.0, 1.3)
		world.say_at(pos, "Lamp's dim!", UI.DIM)
		die("burn")
