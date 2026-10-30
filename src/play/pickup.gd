class_name Pickup
extends Actor
## What's left behind: powder, oil for the lamp, nuggets.

var kind := "nugget"
var vh := 0.0
var alive := true
var life := 24.0
var pull := false


func setup(the_world: World, what: String, at: Vector2, burst := true) -> void:
	world = the_world
	kind = what
	pos = at
	radius = 2.0
	make_sprite(what, kind != "nugget")
	shadow.scale = Vector3(6.0, 1.0, 5.0)
	if burst:
		vel = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0)
		vh = randf_range(60.0, 110.0)
		height = 4.0


func step(dt: float) -> void:
	life -= dt
	if life <= 0.0:
		alive = false
		return
	anim_time += dt
	sprite.play("idle", anim_time)
	if height > 0.0 or vh > 0.0:
		vh -= 300.0 * dt
		height += vh * dt
		if height <= 0.0:
			height = 0.0
			vh = -vh * 0.45 if vh < -30.0 else 0.0
			vel *= 0.5
	else:
		vel *= 0.86
	pos = world.map.move(pos, vel * dt, 2.0)
	if life < 4.0:
		sprite.visible = int(life * 8.0) % 2 == 0
	var player: Player = world.player
	if player.dead:
		return
	var to := player.pos - pos
	var dist := to.length()
	var reach := 26.0
	if kind == "nugget" and world.run.has("greed"):
		reach = 80.0
	if world.exit_open:
		reach = 400.0
	if dist < reach:
		pull = true
	if pull:
		pos += to.normalized() * minf(dist, (150.0 + maxf(reach - dist, 0.0) * 2.0) * dt)
	if dist < 7.0:
		_collect()


func _collect() -> void:
	var run := world.run
	match kind:
		"nugget":
			var worth := Balance.NUGGET_SCORE * (2 if run.has("greed") else 1)
			run.nuggets += 1
			world.add_score(worth)
			Audio.play("nugget", -9.0, randf_range(0.95, 1.25))
		"powder":
			if run.powder >= run.max_powder():
				world.add_score(10)
			run.powder = mini(run.powder + 1, run.max_powder())
			Audio.play("powder", -3.0)
			world.say_at(pos, "+1 powder", Color("ffb347"))
		"oil":
			if run.wicks >= run.max_wicks:
				world.add_score(100)
			world.player.heal(1)
			Audio.play("oil", -2.0)
			world.say_at(pos, "+1 wick", Color("9ff0d8"))
			world.lights.flash(pos, 14.0, Color(1.0, 0.9, 0.6), 0.8, 120.0, 0.5)
	world.hud_refresh()
	alive = false
