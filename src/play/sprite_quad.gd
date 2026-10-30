class_name SpriteQuad
extends MeshInstance3D
## One upright sprite, frames from a sheet (Sheets), drawn pixel for pixel. All
## the sprites of a sheet share a mesh and a shader. Each has its own copy of the
## material to hold its frame and flash: instance uniforms would do it with less,
## but sprites using them go missing in WebGL.

static var _materials := {}
static var _meshes := {}

var sheet := ""
var info: Dictionary
var frame := -1
var uv_rect := Vector4(0.0, 0.0, 1.0, 1.0)
var _flipped := false
var _flash := 0.0
var _material: ShaderMaterial


static func make(sheet_name: String, unlit := false) -> SpriteQuad:
	var q := SpriteQuad.new()
	q.setup(sheet_name, unlit)
	return q


## One that goes over everything: blasts, warnings on the floor.
static func make_over(sheet_name: String) -> SpriteQuad:
	var q := SpriteQuad.new()
	q.setup(sheet_name, true)
	q._use(over_material_for(sheet_name))
	q._send_frame()
	return q


## Its outline, where something's in the way of it.
static func make_ghost(sheet_name: String) -> SpriteQuad:
	var q := SpriteQuad.new()
	q.setup(sheet_name, true)
	var key := sheet_name + "~"
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/shaders/sprite_ghost.gdshader")
		m.set_shader_parameter("albedo_tex", load("res://assets/sprites/%s.png" % sheet_name))
		m.render_priority = 2
		_materials[key] = m
	q._use(_materials[key])
	q._send_frame()
	return q


static func over_material_for(sheet_name: String) -> ShaderMaterial:
	var key := sheet_name + "^"
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/shaders/sprite_over.gdshader")
	m.set_shader_parameter("albedo_tex", load("res://assets/sprites/%s.png" % sheet_name))
	_materials[key] = m
	return m


static func material_for(sheet_name: String, unlit := false) -> ShaderMaterial:
	var key := sheet_name + ("*" if unlit else "")
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/shaders/sprite.gdshader")
	var path := "res://assets/sprites/%s.png" % sheet_name
	m.set_shader_parameter("albedo_tex", load(path))
	var glow_path := "res://assets/sprites/%s_e.png" % sheet_name
	if ResourceLoader.exists(glow_path):
		m.set_shader_parameter("glow_tex", load(glow_path))
	else:
		m.set_shader_parameter("glow_tex", preload("res://assets/sprites/black.png"))
	if unlit:
		m.set_shader_parameter("always_lit", 1.0)
	_materials[key] = m
	return m


static func mesh_for(sheet_name: String) -> QuadMesh:
	if _meshes.has(sheet_name):
		return _meshes[sheet_name]
	var s: Dictionary = Sheets.ALL[sheet_name]
	var m := QuadMesh.new()
	var world_h: float = s.h / Iso.COS
	m.size = Vector2(s.w, world_h)
	# The pivot, the sprite's feet, is at the origin. A little toward the
	# camera, so a sprite on a wall's foot is in front of the wall.
	m.center_offset = Vector3(-s.w * 0.5 + s.w * 0.5, world_h * 0.5 - s.feet / Iso.COS, 0.0)
	_meshes[sheet_name] = m
	return m


## Takes its own copy of this material.
func _use(template: ShaderMaterial) -> void:
	_material = template.duplicate()
	material_override = _material


func setup(sheet_name: String, unlit := false) -> void:
	sheet = sheet_name
	info = Sheets.ALL[sheet_name]
	mesh = mesh_for(sheet_name)
	_use(material_for(sheet_name, unlit))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	custom_aabb = AABB(Vector3(-info.w, -info.h, -8), Vector3(info.w * 2, info.h * 4, 16))
	frame = -1
	show_frame(0)


## Shows frame `index` of the sheet (they go left to right, then down).
func show_frame(index: int) -> void:
	if index == frame:
		return
	frame = index
	var cols: int = info.cols
	var sheet_w: float = info.w * cols
	var sheet_h: float = info.h * info.rows
	uv_rect = Vector4((index % cols) * info.w / sheet_w, (index / cols) * info.h / sheet_h, info.w / sheet_w, info.h / sheet_h)
	_send_frame()


func _send_frame() -> void:
	_material.set_shader_parameter("uv_rect", uv_rect)


## Shows the frame `time` seconds into animation `anim` of the sheet.
func play(anim: String, time: float) -> void:
	var a: Array = info.anims[anim]
	var count: int = a[1]
	var index := int(time * float(a[2]))
	show_frame(a[0] + (index % count if a[3] else mini(index, count - 1)))


func anim_length(anim: String) -> float:
	var a: Array = info.anims[anim]
	return float(a[1]) / float(a[2])


func is_flipped() -> bool:
	return _flipped


func set_flip(flipped: bool) -> void:
	if flipped != _flipped:
		_flipped = flipped
		_material.set_shader_parameter("flip", 1.0 if flipped else 0.0)


## Flashes to `color`, `amount` of the way.
func set_flash(color: Color, amount: float) -> void:
	if amount == _flash and amount == 0.0:
		return
	_flash = amount
	_material.set_shader_parameter("flash", Vector4(color.r, color.g, color.b, amount))


func set_tint(color: Color) -> void:
	_material.set_shader_parameter("tint", Vector4(color.r, color.g, color.b, color.a))


func set_dissolve(amount: float) -> void:
	_material.set_shader_parameter("dissolve", amount)
