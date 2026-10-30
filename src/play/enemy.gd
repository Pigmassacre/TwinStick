class_name Enemy
extends Actor
## Something that lives down here. Asleep in the dark until the lamp, or a noise,
## or an arrow finds it; then each kind goes about it its own way (`think`, in
## src/play/enemies/).

var id := ""
var def: Dictionary
var hp := 1.0
var max_hp := 1.0
var speed := 40.0
var awake := false
var alive := true
var flying := false
var facing := 1.0
var stun_time := 0.0
var burn_time := 0.0
var knock := Vector2.ZERO
var state := 0
var timer := 0.0
var counted := true
## Counted toward clearing the level, or (a boss's rats) not.
var minion := false
var dissolve := 0.0
var _wiggle := randf() * TAU
## Which sheet animation is showing.
var anim := "idle"


func setup(the_world: World, enemy_id: String, at: Vector2) -> void:
	world = the_world
	id = enemy_id
	def = Enemies.DEFS[id]
	pos = at
	radius = def.radius
	hp = float(def.hp) * world.run.enemy_hp_scale()
	max_hp = hp
	speed = float(def.speed) * world.run.enemy_speed_scale()
	flying = def.get("flying", false)
	make_sprite(def.sheet)
	if def.get("boss", false):
		flash_amount = 0.3
	init()
	sync_visual(0.0)


## Overridden: sets itself up.
func init() -> void:
	pass


## Overridden: what it does when it's awake.
func think(_dt: float) -> void:
	pass


## Overridden: nothing can touch it right now (under water, in the ground).
func untouchable() -> bool:
	return false


func step(dt: float) -> void:
	anim_time += dt
	if burn_time > 0.0:
		burn_time -= dt
		if int(burn_time * 8.0) != int((burn_time + dt) * 8.0):
			hurt(0.5, Vector2.ZERO, "burn")
			world.fx.sparks(pos, 8.0, 1, Color(1.0, 0.6, 0.2), 30.0, 0.3)
			if not alive:
				return
		# A burning thing lights the gas it walks through.
		if world.gas.has_gas(Iso.cell_of(pos)):
			world.gas.ignite_near(pos, 8.0)
	if knock.length_squared() > 1.0:
		pos = _moved(knock * dt)
		knock *= pow(0.002, dt)
	if stun_time > 0.0:
		stun_time -= dt
		_show(dt)
		return
	if not awake:
		_sleep(dt)
		_show(dt)
		return
	think(dt)
	_contact()
	_show(dt)


func _sleep(_dt: float) -> void:
	var player: Player = world.player
	var dist := pos.distance_to(player.pos)
	if dist < Balance.WAKE_DISTANCE * world.run.lamp_scale() and world.map.line_clear(pos, player.pos):
		wake()


func wake() -> void:
	if awake:
		return
	awake = true
	on_wake()


## Overridden: it has just noticed you.
func on_wake() -> void:
	pass


func _show(_dt: float) -> void:
	sprite.play(anim, anim_time)
	sprite.set_flip(facing < 0.0)


## Hurts the ranger if touching. Overridden by those that don't touch.
func _contact() -> void:
	if int(def.damage) <= 0 or untouchable():
		return
	var player: Player = world.player
	if not player.can_be_hit():
		return
	var reach: float = radius + player.radius - 1.0
	if pos.distance_squared_to(player.pos) < reach * reach:
		player.hurt(int(def.damage), (player.pos - pos).normalized())


func _moved(delta: Vector2) -> Vector2:
	if flying:
		return pos + delta
	return world.map.move(pos, delta, radius * 0.8)


## Walks toward the ranger along the floor, or straight at them if nothing's in the way.
func walk_to_player(dt: float, scale_by := 1.0) -> void:
	var player: Player = world.player
	var dir: Vector2
	if flying or world.map.line_clear(pos, player.pos):
		dir = (player.pos - pos).normalized()
	else:
		dir = world.map.flow_dir(pos)
		if dir == Vector2.ZERO:
			dir = (player.pos - pos).normalized()
	go(dir, dt, scale_by)


## Keeps its distance: toward the ranger if too far off, away if too close.
func keep_range(dt: float, near_d: float, far_d: float, scale_by := 1.0) -> void:
	var player: Player = world.player
	var dist := pos.distance_to(player.pos)
	if dist > far_d or not world.map.line_clear(pos, player.pos):
		walk_to_player(dt, scale_by)
	elif dist < near_d:
		go((pos - player.pos).normalized(), dt, scale_by)
	else:
		# Sidling.
		_wiggle += dt * 0.7
		go((pos - player.pos).normalized().orthogonal() * sign(sin(_wiggle)), dt, scale_by * 0.5)


func go(dir: Vector2, dt: float, scale_by := 1.0) -> void:
	vel = dir * speed * scale_by
	pos = _moved(vel * dt)
	if absf(dir.x) > 0.1:
		facing = sign(dir.x)


func sees_player() -> bool:
	return world.map.line_clear(pos, world.player.pos)


func to_player() -> Vector2:
	return world.player.pos - pos


func dir_to_player() -> Vector2:
	return (world.player.pos - pos).normalized()


func face_player() -> void:
	var dx := to_player().x
	if absf(dx) > 1.0:
		facing = sign(dx)


## An arrow has struck it. True if it glances off and goes no further.
func struck_by_arrow(s: Shots.Shot) -> bool:
	var dir: Vector2 = s.vel.normalized()
	if def.get("reflects", false):
		world.hint("glance", pos, "Arrows do nothing. Try %s" % "Demolition")
		world.fx.sparks(s.pos, s.h, 4, Color("9ff0d8"), 90.0, 0.25, -dir, 1.4)
		Audio.play("glance", -8.0, randf_range(0.95, 1.25))
		flash(Color("9ff0d8"), 0.05)
		wake()
		return true
	hurt(s.damage, dir, "arrow")
	if s.fire:
		set_burning(2.5)
		if world.gas.has_gas(Iso.cell_of(pos)):
			world.gas.ignite_near(pos, 8.0)
	return false


func set_burning(seconds: float) -> void:
	burn_time = maxf(burn_time, seconds)


func stun(seconds: float) -> void:
	stun_time = maxf(stun_time, seconds * (0.3 if def.get("heavy", false) else 1.0))
	flash(Color(1.0, 1.0, 0.8), 0.1)


## Takes `amount`. `kind`: "arrow", "blast", "burn", "cart".
func hurt(amount: float, from := Vector2.ZERO, kind := "arrow") -> void:
	if not alive:
		return
	wake()
	var damage := _taken(amount, from, kind)
	hp -= damage
	if damage > 0.0:
		flash(Color.WHITE, 0.06)
		if from != Vector2.ZERO and not def.get("heavy", false):
			knock += from * (40.0 if kind == "arrow" else 160.0)
		if kind == "arrow":
			Audio.play("hit", -9.0, randf_range(0.9, 1.15))
			world.fx.blood(pos, 2, def.blood, from)
	if hp <= 0.0:
		die(kind)


## Overridden: how much of it gets through.
func _taken(amount: float, _from: Vector2, _kind: String) -> float:
	return amount


func die(kind := "arrow") -> void:
	if not alive:
		return
	alive = false
	visible = false
	world.enemy_died(self, kind)


func _exit_tree() -> void:
	alive = false
