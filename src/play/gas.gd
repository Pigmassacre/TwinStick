class_name Gas
extends Node3D
## Firedamp: seeps from the rock, drifts along the floor, and goes up all at
## once when anything lights it. And things that are just on fire.

const CAPACITY := 400
const PLANES := 2

var world: World
## cell -> how much, 0 to 1
var amount := {}
## cell -> seconds before it catches
var fuses := {}
## cell -> seconds left burning
var fire := {}
var sources: Array[Vector2i] = []
var _clock := 0.0
var _mesh := MultiMesh.new()
var _material := ShaderMaterial.new()
var _flames: Array[SpriteQuad] = []
var _flame_time := 0.0
var _burn_sound_clock := 0.0
var _dirty := true


func _ready() -> void:
	_mesh.transform_format = MultiMesh.TRANSFORM_3D
	_mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(Iso.TILE + 2, (Iso.TILE + 2) / Iso.SIN)
	_mesh.mesh = quad
	_mesh.instance_count = CAPACITY
	_mesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mesh
	_material.shader = preload("res://src/shaders/gas.gdshader")
	node.material_override = _material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	add_child(node)
	for i in 80:
		var q := SpriteQuad.make("flame", true)
		q.visible = false
		add_child(q)
		_flames.append(q)


func set_color(color: Color) -> void:
	_material.set_shader_parameter("gas_color", color)
	_material.set_shader_parameter("gas_edge", color.darkened(0.45))


func add(cell: Vector2i, value: float) -> void:
	if not world.map.is_floor(cell):
		return
	amount[cell] = minf(float(amount.get(cell, 0.0)) + value, 1.0)


## Puffs gas out around `p`, thick in the middle.
func puff(p: Vector2, how_much: float, spread := 1) -> void:
	var c := Iso.cell_of(p)
	for x in range(-spread, spread + 1):
		for y in range(-spread, spread + 1):
			var off := Vector2i(x, y)
			add(c + off, how_much * (1.0 if off == Vector2i.ZERO else 0.5))


func has_gas(cell: Vector2i) -> bool:
	return float(amount.get(cell, 0.0)) > 0.12


## Lights whatever gas is within `r` of `p`.
func ignite_near(p: Vector2, r: float) -> void:
	var c := Iso.cell_of(p)
	var cells := ceili(r / Iso.TILE)
	for x in range(-cells, cells + 1):
		for y in range(-cells, cells + 1):
			var n := c + Vector2i(x, y)
			if has_gas(n) and Iso.cell_center(n).distance_to(p) <= r + 8.0:
				_light(n, 0.0)


func _light(cell: Vector2i, delay: float) -> void:
	if not fuses.has(cell) and not fire.has(cell):
		fuses[cell] = delay


## Sets a cell burning for `seconds`, gas or no gas.
func set_fire(cell: Vector2i, seconds: float) -> void:
	if world.map.is_floor(cell):
		fire[cell] = maxf(float(fire.get(cell, 0.0)), seconds)


func burning_at(p: Vector2) -> bool:
	return fire.has(Iso.cell_of(p))


func step(dt: float) -> void:
	_clock += dt
	_flame_time += dt
	_burn_sound_clock -= dt
	if _clock >= 0.25:
		_clock = 0.0
		_drift()
	# What's on a fuse catches, and passes it on: it runs through a cloud in a rush.
	if not fuses.is_empty():
		for cell: Vector2i in fuses.keys():
			fuses[cell] -= dt
			if fuses[cell] <= 0.0:
				fuses.erase(cell)
				_catch(cell)
	if not fire.is_empty():
		for cell: Vector2i in fire.keys():
			fire[cell] -= dt
			if fire[cell] <= 0.0:
				fire.erase(cell)
			elif has_gas(cell):
				_catch(cell)
		_burn_things(dt)
	_dirty = true


func _drift() -> void:
	for c in sources:
		add(c, 0.5)
	var next := {}
	for cell: Vector2i in amount:
		var v: float = amount[cell] * 0.994
		# It spreads, thinly, to the floor around it.
		var share := v * 0.09
		var kept := v
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cell + d
			if world.map.is_floor(n):
				next[n] = float(next.get(n, 0.0)) + share
				kept -= share
		next[cell] = float(next.get(cell, 0.0)) + kept
	amount.clear()
	for cell: Vector2i in next:
		var v: float = next[cell]
		if v > 0.05:
			amount[cell] = minf(v, 1.0)
	# A hard limit on how far a cloud goes.
	if amount.size() > CAPACITY / PLANES:
		var cells := amount.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return amount[a] > amount[b])
		for i in range(CAPACITY / PLANES, cells.size()):
			amount.erase(cells[i])


func _catch(cell: Vector2i) -> void:
	var how_much: float = amount.get(cell, 0.0)
	amount.erase(cell)
	if how_much <= 0.0:
		return
	fire[cell] = 0.6 + how_much * 0.5
	var at := Iso.cell_center(cell)
	world.gas_burst(at, how_much)
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n: Vector2i = cell + d
		if has_gas(n):
			_light(n, randf_range(0.03, 0.08))


func _burn_things(_dt: float) -> void:
	# On anything standing in it, a little every time it's looked at.
	var player: Player = world.player
	if burning_at(player.pos) and player.can_be_hit():
		player.hurt(1)
	for e: Enemy in world.enemies:
		if e.height < 8.0 and burning_at(e.pos) and not e.def.get("flame_proof", false):
			e.set_burning(1.5)


func _process(_delta: float) -> void:
	if not _dirty:
		return
	_dirty = false
	var count := 0
	var t := Transform3D.IDENTITY
	for cell: Vector2i in amount:
		if count + PLANES > CAPACITY:
			break
		var center := Iso.cell_center(cell)
		for p in PLANES:
			t.origin = Iso.at(center, 3.0 + p * 9.0)
			_mesh.set_instance_transform(count, t)
			_mesh.set_instance_custom_data(count, Color(float(amount[cell]) * (1.0 - p * 0.2), 0.0, 0.0, 0.0))
			count += 1
	_mesh.visible_instance_count = count
	var i := 0
	for cell: Vector2i in fire:
		if i >= _flames.size():
			break
		var q := _flames[i]
		q.visible = true
		q.position = Iso.snapped(Iso.cell_center(cell) + Vector2(0.0, 7.0))
		q.show_frame((int(_flame_time * 12.0) + cell.x * 2 + cell.y) % 3)
		i += 1
	for k in range(i, _flames.size()):
		if not _flames[k].visible:
			break
		_flames[k].visible = false
