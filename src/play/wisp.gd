class_name Wisp
extends Actor
## The Will-o'-Wisp: goes round the ranger, shooting what it can see, and takes
## a shot for you now and then.

var phase := 0.0
var cooldown := 0.0
var rest := 0.0


func setup(the_world: World, at_phase: float) -> void:
	world = the_world
	phase = at_phase
	pos = world.player.pos
	height = 12.0
	make_sprite("wisp", true)
	shadow.visible = false


func step(dt: float) -> void:
	phase += dt * 2.4
	rest = maxf(rest - dt, 0.0)
	cooldown -= dt
	var want: Vector2 = world.player.pos + Vector2.from_angle(phase) * Vector2(20.0, 15.0)
	pos = pos.lerp(want, 1.0 - exp(-dt * 10.0))
	anim_time += dt
	sprite.play("idle", anim_time)
	sprite.visible = rest <= 0.0 or int(rest * 12.0) % 2 == 0
	if cooldown <= 0.0 and rest <= 0.0:
		var e: Enemy = world.nearest_enemy(pos, 130.0)
		if e and world.map.line_clear(pos, e.pos):
			cooldown = 0.55
			var s := Shots.Shot.new()
			s.friendly = true
			s.pos = pos
			s.vel = (e.pos - pos).normalized() * 300.0
			s.h = height
			s.life = 0.7
			s.damage = 1.5
			s.frame = Shots.ORB
			s.turns = false
			world.shots.list.append(s)
			Audio.play("wisp", -14.0, randf_range(1.2, 1.4))


func blocked() -> void:
	rest = 1.5
	world.fx.sparks(pos, height, 6, Color(0.8, 0.6, 1.0), 60.0, 0.25)
