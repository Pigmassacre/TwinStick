extends Enemy
## A gloam: a bit of the dark that has learned to want things. Comes through the
## walls, slowly in the light and quickly out of it, and in the light it can be hurt.

const SHOOT_EVERY := 2.2


func init() -> void:
	height = 5.0
	timer = randf_range(1.0, SHOOT_EVERY)
	anim = "idle"


func think(dt: float) -> void:
	var dist := to_player().length()
	var lit := dist < world.player.lamp_reach() * 0.52
	var pace := 0.6 if lit else 1.5
	height = 5.0 + sin(anim_time * 2.2) * 2.0
	if dist > 70.0:
		go(dir_to_player(), dt, pace)
	else:
		go(dir_to_player().orthogonal(), dt, pace * 0.7)
	sprite.set_tint(Color(1.0, 1.0, 1.0, 1.0))
	sprite.set_dissolve(0.0 if lit else 0.45)
	timer -= dt
	if timer <= 0.0:
		timer = SHOOT_EVERY + randf_range(-0.3, 0.5)
		var s := world.shots.enemy(pos, dir_to_player(), 56.0, Shots.ORB, 1.0, 5.0)
		s.h = 8.0
		s.accel = 16.0
		Audio.play("wraith", -9.0, randf_range(0.9, 1.1))


func _taken(amount: float, _from: Vector2, _kind: String) -> float:
	var lit := to_player().length() < world.player.lamp_reach() * 0.52
	if not lit:
		world.hint("gloam", pos, "Only the light can touch them")
	return amount if lit else amount * 0.4


func die(kind := "arrow") -> void:
	if alive and world:
		world.fx.sparks(pos, 8.0, 12, Color("c78cff"), 60.0, 0.6)
		Audio.play("wraith", -5.0, 0.7)
	super.die(kind)
