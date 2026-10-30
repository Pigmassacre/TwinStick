extends Enemy
## Small, quick, soot-black and after one thing. It doesn't bite: it gets on the
## lamp and sits there, and you can't see a thing until you roll it off.

var riding := false
var ride_time := 0.0


func init() -> void:
	anim = "idle"


func think(dt: float) -> void:
	var player: Player = world.player
	if riding:
		ride_time += dt
		pos = player.pos + Vector2(0.0, 1.0)
		height = 19.0
		player.snuffed = maxf(player.snuffed, 0.2)
		if player.roll_time > 0.0:
			_thrown_off()
		elif ride_time > 5.0:
			_thrown_off()
		return
	walk_to_player(dt)
	if to_player().length() < 9.0 and player.roll_time <= 0.0 and not player.dead:
		riding = true
		ride_time = 0.0
		Audio.play("snuff", -3.0)
		world.say_at(pos, "It's on the lamp!", Color("c0bec8"))


func _thrown_off() -> void:
	riding = false
	height = 0.0
	knock = Vector2.from_angle(randf() * TAU) * 180.0
	stun(0.8)
	Audio.play("rat", -6.0, 1.5)


func _contact() -> void:
	pass
