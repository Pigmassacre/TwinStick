class_name Shots
extends Node3D
## Everything flying: the ranger's arrows and charges, and what comes the other
## way. Plain objects, drawn together in one MultiMesh.

const CAPACITY := 600
enum {
	ARROW, CHARGE, NAIL, SPIT, EMBER, SHARD, DROP, ORB, SMALL, BIG, HOT, COAL, GAS, BOSS_ORB, HEAVY_ARROW, FIRE_ARROW,
}

class Shot:
	var alive := true
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var h := Balance.ARROW_HEIGHT
	var life := 1.0
	var damage := 1.0
	var friendly := false
	var frame := ARROW
	var turns := true
	var spin := 0.0
	var angle := 0.0
	var size := 1.0
	var radius := 2.0
	var pierce := 0
	var bounces := 0
	var homing := 0.0
	var explosive := false
	var blast_radius := 0.0
	var blast_damage := 0.0
	var fire := false
	## Thrown in an arc: it lands when h is 0, wherever that is.
	var lobbed := false
	var vh := 0.0
	var on_land := ""
	## What it has been through (a piercing arrow hits each thing once).
	var hit := {}
	## Curving: turns this much a second.
	var curve := 0.0
	var accel := 0.0

var world: World
var list: Array[Shot] = []
var _mesh := MultiMesh.new()
var _dirty := true


func _ready() -> void:
	_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(16, 16)
	_mesh.mesh = quad
	_mesh.instance_count = CAPACITY
	_mesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/shaders/shot.gdshader")
	material.set_shader_parameter("albedo_tex", preload("res://assets/sprites/shots.png"))
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	add_child(node)


## Something the mine throws at the ranger.
func enemy(from: Vector2, dir: Vector2, speed: float, frame := SMALL, damage := 1.0, life := 4.0) -> Shot:
	if list.size() >= CAPACITY:
		return Shot.new()
	var s := Shot.new()
	s.pos = from
	s.vel = dir.normalized() * speed
	s.frame = frame
	s.turns = frame in [NAIL, SHARD, ARROW]
	s.angle = s.vel.angle()
	s.damage = damage
	s.life = life
	s.h = 7.0
	s.radius = 2.5 if frame != BIG and frame != BOSS_ORB else 4.0
	list.append(s)
	return s


## n of them in a ring.
func ring(from: Vector2, n: int, speed: float, frame := SMALL, offset := 0.0, damage := 1.0) -> void:
	for i in n:
		enemy(from, Vector2.from_angle(offset + TAU * i / n), speed, frame, damage)


## n of them in a fan `width` radians wide, about `dir`.
func fan(from: Vector2, dir: Vector2, n: int, width: float, speed: float, frame := SMALL, damage := 1.0) -> void:
	var a := dir.angle()
	for i in n:
		var t := 0.0 if n == 1 else float(i) / (n - 1) - 0.5
		enemy(from, Vector2.from_angle(a + t * width), speed, frame, damage)


## An arc from `from` to `to`, taking `seconds`, doing what `on_land` says when it comes down.
func lob(from: Vector2, to: Vector2, seconds: float, frame := SPIT, on_land := "gas", top := 40.0) -> Shot:
	var s := enemy(from, Vector2.RIGHT, 0.0, frame)
	s.vel = (to - from) / seconds
	s.lobbed = true
	s.life = seconds + 1.0
	s.h = 8.0
	s.vh = (top * 4.0) / seconds
	s.on_land = on_land
	s.turns = false
	return s


func clear_enemy_shots(burst := true) -> void:
	for s in list:
		if not s.friendly and s.alive:
			s.alive = false
			if burst:
				world.fx.sparks(s.pos, s.h, 2, Color(1.0, 0.7, 0.3), 40.0, 0.2)


func step(dt: float) -> void:
	var player: Player = world.player
	var i := list.size() - 1
	while i >= 0:
		var s := list[i]
		if s.alive:
			_step_shot(s, dt, player)
		if not s.alive:
			list.remove_at(i)
		i -= 1
	_dirty = true


func _step_shot(s: Shot, dt: float, player: Player) -> void:
	s.life -= dt
	if s.life <= 0.0:
		if s.explosive:
			world.detonate(s)
		s.alive = false
		return
	if s.homing > 0.0:
		var near: Enemy = world.nearest_enemy(s.pos, 90.0)
		if near:
			var want := (near.pos - s.pos).angle()
			var a := rotate_toward(s.vel.angle(), want, s.homing * dt)
			s.vel = Vector2.from_angle(a) * s.vel.length()
	if s.curve != 0.0:
		s.vel = s.vel.rotated(s.curve * dt)
	if s.accel != 0.0:
		s.vel = s.vel.normalized() * maxf(s.vel.length() + s.accel * dt, 10.0)
	if s.lobbed:
		s.vh -= 8.0 * 40.0 * dt
		s.h += s.vh * dt
		s.pos += s.vel * dt
		if s.h <= 0.0:
			s.h = 0.0
			s.alive = false
			world.shot_landed(s)
		return
	var next := s.pos + s.vel * dt
	if world.map.wall_at(next):
		if s.bounces > 0 and s.friendly:
			s.bounces -= 1
			# Which way it hit: glance off that side.
			if world.map.wall_at(Vector2(next.x, s.pos.y)):
				s.vel.x = -s.vel.x
			if world.map.wall_at(Vector2(s.pos.x, next.y)):
				s.vel.y = -s.vel.y
			world.fx.sparks(s.pos, s.h, 2, Color(1.0, 0.9, 0.6), 50.0, 0.2)
			s.hit.clear()
			Audio.play("ricochet", -8.0, randf_range(0.95, 1.2))
			return
		s.pos = next
		world.shot_hit_wall(s)
		s.alive = false
		return
	s.pos = next
	if s.friendly:
		_hit_things(s)
	elif s.frame != SPIT:
		if player.can_be_hit() and s.pos.distance_squared_to(player.pos) < (s.radius + player.radius) * (s.radius + player.radius):
			s.alive = false
			player.hurt(1, s.vel.normalized())
			world.fx.sparks(s.pos, s.h, 5, Color(1.0, 0.6, 0.3), 70.0, 0.25)
			return
		# The wisp takes what it can.
		for wisp: Wisp in world.wisps:
			if s.pos.distance_squared_to(wisp.pos) < 36.0:
				s.alive = false
				wisp.blocked()
				return


func _hit_things(s: Shot) -> void:
	for e: Enemy in world.enemies:
		if not e.alive or e.untouchable() or s.hit.has(e):
			continue
		var reach: float = s.radius + e.radius
		var d := s.pos - e.pos
		if absf(d.x) > reach or absf(d.y) > reach or d.length_squared() > reach * reach:
			continue
		s.hit[e] = true
		if s.explosive:
			world.detonate(s)
			s.alive = false
			return
		var bounced: bool = e.struck_by_arrow(s)
		if bounced:
			s.alive = false
			return
		if s.pierce > 0:
			s.pierce -= 1
		else:
			s.alive = false
			return
	# Crates and kegs and carts stop arrows too.
	var cell := Iso.cell_of(s.pos)
	if world.map.props.has(cell):
		var prop: Prop = world.map.props[cell]
		prop.struck(s)
		if s.explosive:
			world.detonate(s)
		s.alive = false
		return
	for cart: Prop in world.carts:
		if s.pos.distance_squared_to(cart.pos) < 64.0:
			cart.struck(s)
			if s.explosive:
				world.detonate(s)
			s.alive = false
			return


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	var count := mini(list.size(), CAPACITY)
	_mesh.visible_instance_count = count
	var t := Transform3D.IDENTITY
	for i in count:
		var s := list[i]
		t.origin = Vector3(round(s.pos.x), round(s.h) / Iso.COS, round(s.pos.y) / Iso.SIN)
		_mesh.set_instance_transform(i, t)
		var angle := s.vel.angle() if s.turns else s.angle
		# The screen's y is up: an arrow flying down the screen points down.
		_mesh.set_instance_custom_data(i, Color(float(s.frame % 8), float(s.frame / 8), -angle, s.size))
