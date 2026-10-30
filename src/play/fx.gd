class_name Fx
extends Node3D
## All the little bits: sparks, chips of wall, blood, smoke; and the sprite
## effects that play once and go.

const CAPACITY := 1400

class Bit:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var h := 0.0
	var vh := 0.0
	var life := 0.0
	var size := 1.0
	var shine := 0.0
	var color := Color.WHITE
	var gravity := 240.0
	var bounces := true
	var drag := 1.0

class Effect:
	var quad: SpriteQuad
	var time := 0.0
	var length := 0.0
	var pos := Vector2.ZERO
	var h := 0.0
	var vh := 0.0

var world: World
var _bits: Array[Bit] = []
var _free_bits: Array[Bit] = []
var _mesh := MultiMesh.new()
var _effects: Array[Effect] = []
var _idle := {}
var _dirty := true


func _ready() -> void:
	_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_mesh.use_colors = true
	_mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_mesh.mesh = quad
	_mesh.instance_count = CAPACITY
	_mesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/shaders/spark.gdshader")
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	add_child(node)
	for i in CAPACITY:
		_free_bits.append(Bit.new())


func _add(pos: Vector2, h: float, vel: Vector2, vh: float, life: float, color: Color, size := 1.0, shine := 0.0) -> Bit:
	var b: Bit
	if _free_bits.is_empty():
		b = _bits[0]
		_bits.remove_at(0)
	else:
		b = _free_bits.pop_back()
	b.pos = pos
	b.h = h
	b.vel = vel
	b.vh = vh
	b.life = life
	b.color = color
	b.size = size
	b.shine = shine
	b.gravity = 240.0
	b.bounces = true
	b.drag = 1.0
	_bits.append(b)
	return b


## Sparks: they shine by themselves, fly, and go out.
func sparks(pos: Vector2, h: float, count: int, color: Color, speed := 90.0, life := 0.35, dir := Vector2.ZERO, spread := TAU) -> void:
	for i in count:
		var a := randf() * TAU if dir == Vector2.ZERO else dir.angle() + randf_range(-spread, spread) * 0.5
		var v := Vector2.from_angle(a) * speed * randf_range(0.4, 1.0)
		var b := _add(pos, h, v, randf_range(10.0, 80.0), life * randf_range(0.5, 1.0), color, 1.0, 1.4)
		b.gravity = 160.0
		b.bounces = false


## Chips of something solid: they're lit like the world, land, and lie there a while.
func chips(pos: Vector2, h: float, count: int, color: Color, speed := 70.0, life := 2.0, size := 1.0) -> void:
	for i in count:
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.3, 1.0)
		var shade := color.darkened(randf_range(0.0, 0.35))
		_add(pos, h, v, randf_range(30.0, 110.0), life * randf_range(0.6, 1.0), shade, size)


## What comes out of things that have been hit.
func blood(pos: Vector2, count: int, color: Color, dir := Vector2.ZERO) -> void:
	for i in count:
		var a := randf() * TAU if dir == Vector2.ZERO else dir.angle() + randf_range(-0.8, 0.8)
		var v := Vector2.from_angle(a) * randf_range(20.0, 90.0)
		_add(pos, randf_range(3.0, 9.0), v, randf_range(20.0, 70.0), randf_range(1.2, 3.5), color.darkened(randf_range(0.0, 0.3)))


## Dust or smoke going up.
func smoke(pos: Vector2, h: float, count: int, color := Color(0.25, 0.23, 0.27), spread := 8.0) -> void:
	for i in count:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(4.0, 18.0)
		var b := _add(pos + Vector2.from_angle(randf() * TAU) * randf() * spread, h, v, randf_range(14.0, 36.0), randf_range(0.5, 1.3), color, randf_range(1.0, 3.0))
		b.gravity = -6.0
		b.bounces = false
		b.drag = 0.97


## An arrow left stuck in the wall a while: a few bits in a line.
func stuck_arrow(at: Vector2, h: float, dir: Vector2) -> void:
	for i in 4:
		var b := _add(at - dir * i, h, Vector2.ZERO, 0.0, 5.0, Color("99915a") if i > 0 else Color("c9bd84"))
		b.gravity = 0.0
		b.bounces = false


## Plays a sprite sheet's `anim` where `p` is, over everything: once through, or for `seconds`.
func play(sheet: String, p: Vector2, h := 0.0, anim := "idle", _unlit := true, scale_by := 1.0, rise := 0.0, seconds := 0.0) -> void:
	var pool: Array = _idle.get(sheet, [])
	var e: Effect
	if pool.is_empty():
		e = Effect.new()
		e.quad = SpriteQuad.make_over(sheet)
		add_child(e.quad)
	else:
		e = pool.pop_back()
	e.quad.visible = true
	e.quad.scale = Vector3(scale_by, scale_by, 1.0)
	e.time = 0.0
	e.length = seconds if seconds > 0.0 else e.quad.anim_length(anim)
	e.pos = p
	e.h = h
	e.vh = rise
	e.quad.set_meta("anim", anim)
	e.quad.position = Iso.snapped(p, h)
	e.quad.play(anim, 0.0)
	_effects.append(e)


func step(dt: float) -> void:
	var i := _bits.size() - 1
	while i >= 0:
		var b := _bits[i]
		b.life -= dt
		if b.life <= 0.0:
			_bits.remove_at(i)
			_free_bits.append(b)
			i -= 1
			continue
		if b.gravity != 0.0 or b.h > 0.0:
			var next := b.pos + b.vel * dt
			if b.vel != Vector2.ZERO and world.map.wall_at(next) and b.h < 8.0:
				b.vel = -b.vel * 0.3
			else:
				b.pos = next
			b.vh -= b.gravity * dt
			b.h += b.vh * dt
			b.vel *= b.drag
			if b.h <= 0.0:
				b.h = 0.0
				if b.bounces and absf(b.vh) > 22.0:
					b.vh = -b.vh * 0.4
					b.vel *= 0.5
				else:
					b.vh = 0.0
					b.vel = Vector2.ZERO
					b.gravity = 0.0
		i -= 1
	i = _effects.size() - 1
	while i >= 0:
		var e := _effects[i]
		e.time += dt
		if e.time >= e.length:
			e.quad.visible = false
			if not _idle.has(e.quad.sheet):
				_idle[e.quad.sheet] = []
			_idle[e.quad.sheet].append(e)
			_effects.remove_at(i)
		else:
			e.quad.play(e.quad.get_meta("anim"), e.time)
			if e.vh != 0.0:
				e.h += e.vh * dt
				e.quad.position = Iso.snapped(e.pos, e.h)
		i -= 1
	_dirty = true


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	var count := _bits.size()
	_mesh.visible_instance_count = count
	var t := Transform3D.IDENTITY
	for i in count:
		var b := _bits[i]
		t.origin = Iso.snapped(b.pos, b.h)
		_mesh.set_instance_transform(i, t)
		_mesh.set_instance_color(i, b.color)
		_mesh.set_instance_custom_data(i, Color(b.size, b.shine, 0.0, 0.0))
