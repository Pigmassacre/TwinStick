class_name MapView
extends Node3D
## Draws the LevelMap: floors, walls and their shadows, as a mesh for each
## chunk of it, built again when a wall comes down.

const CHUNK := 8
const OVERLAY_RAIL_H := 0
const OVERLAY_RAIL_V := 1
## Roof heights. A wall's height is 10 where it has floor just north of it, so
## nothing walks around behind a wall and out of sight, and it rises going south.
const LOW := 10
const TALL := 24

const ATLAS_W := 128.0
const ATLAS_H := 120.0

var map: LevelMap
var depth_id := ""
var _tile_material: ShaderMaterial
var _overlay_material: ShaderMaterial
var _shadow_material := StandardMaterial3D.new()
## chunk -> [visible MeshInstance3D, shadow-only MeshInstance3D]
var _chunks := {}
var _dirty := {}
## Per cell, a little random number for which tile it gets.
var _noise := PackedByteArray()


func setup(level: LevelMap, depth: String, seed_value: int) -> void:
	map = level
	depth_id = depth
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_noise.resize(map.w * map.h)
	for i in _noise.size():
		_noise[i] = rng.randi() % 256
	var albedo: Texture2D = load("res://assets/tiles/%s.png" % depth)
	_tile_material = ShaderMaterial.new()
	_tile_material.shader = preload("res://src/shaders/tile.gdshader")
	_tile_material.set_shader_parameter("albedo_tex", albedo)
	_tile_material.set_shader_parameter("normal_tex", load("res://assets/tiles/%s_n.png" % depth))
	_tile_material.set_shader_parameter("emission_tex", load("res://assets/tiles/%s_e.png" % depth))
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = preload("res://src/shaders/overlay.gdshader")
	_overlay_material.set_shader_parameter("albedo_tex", albedo)
	_overlay_material.render_priority = -1
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for y in range(0, map.h, CHUNK):
		for x in range(0, map.w, CHUNK):
			_build(Vector2i(x / CHUNK, y / CHUNK))


## The walls have changed in this cell: its chunks are built again this frame.
func touch(c: Vector2i) -> void:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1, 2]:
			var n: Vector2i = c + Vector2i(dx, dy)
			_dirty[Vector2i(floori(float(n.x) / CHUNK), floori(float(n.y) / CHUNK))] = true


func flush() -> void:
	for chunk: Vector2i in _dirty:
		if chunk.x >= 0 and chunk.y >= 0 and chunk.x * CHUNK < map.w and chunk.y * CHUNK < map.h:
			_build(chunk)
	_dirty.clear()


## How high the wall in this cell is (see LOW and TALL).
func height_of(c: Vector2i) -> int:
	var k := 0
	var at := c + Vector2i.UP
	while k < 3 and map.is_wall(at):
		k += 1
		at += Vector2i.UP
	if k == 3:
		return TALL
	return mini(TALL, LOW + 16 * k)


func _build(chunk: Vector2i) -> void:
	var t := _Quads.new()
	var o := _Quads.new()
	var s := _Quads.new()
	for y in range(chunk.y * CHUNK, mini((chunk.y + 1) * CHUNK, map.h)):
		for x in range(chunk.x * CHUNK, mini((chunk.x + 1) * CHUNK, map.w)):
			var c := Vector2i(x, y)
			if map.is_wall(c):
				_wall(c, t, s)
			else:
				_floor(c, t, o)
	var pair: Array = _chunks.get(chunk, [])
	if pair.is_empty():
		var visible_mesh := MeshInstance3D.new()
		visible_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visible_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(visible_mesh)
		var shadow_mesh := MeshInstance3D.new()
		shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(shadow_mesh)
		pair = [visible_mesh, shadow_mesh]
		_chunks[chunk] = pair
	var mesh := ArrayMesh.new()
	t.commit(mesh, _tile_material)
	o.commit(mesh, _overlay_material)
	pair[0].mesh = mesh
	var shadow := ArrayMesh.new()
	s.commit(shadow, _shadow_material)
	pair[1].mesh = shadow


func _noise_at(c: Vector2i) -> int:
	return _noise[c.y * map.w + c.x] if map.inside(c) else 0


func _uv(x: int, y: int, w: int, h: int) -> Rect2:
	return Rect2(x / ATLAS_W, y / ATLAS_H, w / ATLAS_W, h / ATLAS_H)


func _floor(c: Vector2i, t: _Quads, o: _Quads) -> void:
	var n := _noise_at(c)
	var tile := n % 16 if n % 3 == 0 else 8 + n % 8
	t.flat(c, 0.0, _uv((tile % 8) * 16, (tile / 8) * 16, 16, 16))
	# What lies on it.
	if map.overlays.has(c):
		var overlay: int = map.overlays[c]
		o.flat(c, 0.15, _uv(overlay * 16, 88, 16, 16))
	elif n % 11 == 0:
		o.flat(c, 0.1, _uv((6 + (n >> 4) % 2) * 16, 88, 16, 16))
	elif n % 13 == 1:
		o.flat(c, 0.1, _uv((1 + (n >> 4) % 2) * 16, 104, 16, 16))
	elif n % 17 == 2:
		o.flat(c, 0.1, _uv((4 + (n >> 4) % 4) * 16, 104, 16, 16))
	# The dark pooled at the foot of the wall to the north.
	if map.is_wall(c + Vector2i.UP):
		o.flat(c, 0.2, _uv(0, 104, 16, 16))


func _wall(c: Vector2i, t: _Quads, s: _Quads) -> void:
	var h := height_of(c)
	var n := _noise_at(c)
	# The roof, its edge drawn on the sides nothing higher stands.
	var bits := 0
	var north := c + Vector2i.UP
	if map.is_floor(north) or (map.is_wall(north) and height_of(north) < h):
		bits |= 1
	if map.is_floor(c + Vector2i.RIGHT):
		bits |= 2
	if map.is_floor(c + Vector2i.DOWN):
		bits |= 4
	if map.is_floor(c + Vector2i.LEFT):
		bits |= 8
	t.flat(c, h, _uv((bits % 8) * 16, 32 + (bits / 8) * 16, 16, 16))
	# The face, if floor lies south of it.
	if map.is_floor(c + Vector2i.DOWN):
		var variant := n % 6
		if map.cracked.has(c):
			variant = 6
		elif map.lamps.has(c):
			variant = 7
		t.front(c, h, _uv(variant * 16, 64 + TALL - h, 16, h))
	# The shadow it throws. A low wall lets the light over it.
	if h > LOW or map.kind(c) == LevelMap.BEDROCK:
		s.box(c, TALL + 4)


## Quads being gathered into a surface.
class _Quads:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, normal: Vector3, uv: Rect2) -> void:
		var i := verts.size()
		verts.append_array([a, b, cc, d])
		for k in 4:
			normals.append(normal)
			tangents.append_array([1.0, 0.0, 0.0, 1.0])
		uvs.append_array([uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)])
		indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])

	## Lying flat on cell `c`, `h` pixels up, its top to the north.
	func flat(c: Vector2i, h: float, uv: Rect2) -> void:
		var x0 := float(c.x * Iso.TILE)
		var y0 := float(c.y * Iso.TILE)
		var x1 := x0 + Iso.TILE
		var y1 := y0 + Iso.TILE
		quad(Iso.at(Vector2(x0, y0), h), Iso.at(Vector2(x1, y0), h), Iso.at(Vector2(x1, y1), h), Iso.at(Vector2(x0, y1), h), Vector3.UP, uv)

	## Standing on the south edge of cell `c`, `h` pixels high.
	func front(c: Vector2i, h: float, uv: Rect2) -> void:
		var x0 := float(c.x * Iso.TILE)
		var x1 := x0 + Iso.TILE
		var y := float((c.y + 1) * Iso.TILE)
		quad(Iso.at(Vector2(x0, y), h), Iso.at(Vector2(x1, y), h), Iso.at(Vector2(x1, y), 0.0), Iso.at(Vector2(x0, y), 0.0), Vector3.BACK, uv)

	## A block on cell `c`, for its shadow.
	func box(c: Vector2i, h: float) -> void:
		var x0 := float(c.x * Iso.TILE)
		var y0 := float(c.y * Iso.TILE)
		var x1 := x0 + Iso.TILE
		var y1 := y0 + Iso.TILE
		var none := Rect2()
		var a := Iso.at(Vector2(x0, y0), h)
		var b := Iso.at(Vector2(x1, y0), h)
		var cc := Iso.at(Vector2(x1, y1), h)
		var d := Iso.at(Vector2(x0, y1), h)
		var e := Iso.at(Vector2(x0, y0), 0.0)
		var f := Iso.at(Vector2(x1, y0), 0.0)
		var g := Iso.at(Vector2(x1, y1), 0.0)
		var i := Iso.at(Vector2(x0, y1), 0.0)
		quad(a, b, cc, d, Vector3.UP, none)
		quad(d, cc, g, i, Vector3.BACK, none)
		quad(b, a, e, f, Vector3.FORWARD, none)
		quad(cc, b, f, g, Vector3.RIGHT, none)
		quad(a, d, i, e, Vector3.LEFT, none)

	func commit(mesh: ArrayMesh, material: Material) -> void:
		if verts.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
