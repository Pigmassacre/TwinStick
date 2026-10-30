class_name Actor
extends Node3D
## Anything that walks or flies around: where it is on the plane of the floor,
## and the sprite that shows it.

var world: World
var pos := Vector2.ZERO
var vel := Vector2.ZERO
## Off the floor, in pixels.
var height := 0.0
var radius := 5.0
var sprite: SpriteQuad
var shadow: MeshInstance3D
var anim_time := 0.0
var flash_time := 0.0
var flash_color := Color.WHITE
## How far a flash goes. The big ones get hit all the time, and are still to be seen.
var flash_amount := 1.0

var long_shadow: MeshInstance3D
var _long_material: ShaderMaterial

static var _blob_mesh: QuadMesh
static var _blob_material: ShaderMaterial
static var _long_mesh: QuadMesh
static var _long_materials := {}


func make_sprite(sheet: String, unlit := false) -> void:
	sprite = SpriteQuad.make(sheet, unlit)
	add_child(sprite)
	if _blob_mesh == null:
		_blob_mesh = QuadMesh.new()
		_blob_mesh.orientation = PlaneMesh.FACE_Y
		_blob_mesh.size = Vector2(1, 1)
		_blob_material = ShaderMaterial.new()
		_blob_material.shader = preload("res://src/shaders/blob.gdshader")
		_blob_material.render_priority = 1
	shadow = MeshInstance3D.new()
	shadow.mesh = _blob_mesh
	shadow.material_override = _blob_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.scale = Vector3(radius * 2.6, 1.0, radius * 1.8 / Iso.SIN)
	shadow.position.y = 0.5
	add_child(shadow)


## Lays this sprite's shadow out across the floor, away from `lamp`, if the lamp reaches it.
func cast_long_shadow(lamp: Vector2, reach: float) -> void:
	if sprite == null:
		return
	var to := pos - lamp
	var dist := to.length()
	if dist > reach or dist < 7.0 or height > 12.0 or not visible:
		if long_shadow:
			long_shadow.visible = false
		return
	if long_shadow == null:
		_make_long_shadow()
	long_shadow.visible = true
	var dir := to / dist
	var length := clampf(9.0 + dist * 0.2, 9.0, 34.0)
	var width: float = sprite.info.w
	# Flat on the floor, its top pointing away from the lamp.
	var along := Vector3(dir.x, 0.0, dir.y / Iso.SIN) * length
	var across := Vector3(dir.y, 0.0, -dir.x / Iso.SIN) * width
	long_shadow.transform = Transform3D(Basis(across, Vector3.UP, -along), Vector3(0.0, 0.6 - round(height) / Iso.COS, 0.0))
	_long_material.set_shader_parameter("uv_rect", sprite.uv_rect)
	_long_material.set_shader_parameter("flip", 1.0 if sprite.is_flipped() else 0.0)
	_long_material.set_shader_parameter("strength", clampf(1.2 - dist / reach * 1.2, 0.0, 0.8))


func _make_long_shadow() -> void:
	if _long_mesh == null:
		_long_mesh = QuadMesh.new()
		_long_mesh.orientation = PlaneMesh.FACE_Y
		_long_mesh.size = Vector2(1, 1)
		_long_mesh.center_offset = Vector3(0.0, 0.0, -0.5)
	var sheet: String = sprite.sheet
	if not _long_materials.has(sheet):
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/shaders/sprite_shadow.gdshader")
		m.set_shader_parameter("albedo_tex", load("res://assets/sprites/%s.png" % sheet))
		_long_materials[sheet] = m
	_long_material = _long_materials[sheet].duplicate()
	long_shadow = MeshInstance3D.new()
	long_shadow.mesh = _long_mesh
	long_shadow.material_override = _long_material
	long_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(long_shadow)


func sync_visual(dt: float) -> void:
	position = Iso.snapped(pos, height)
	if shadow:
		shadow.position.y = 0.5 - round(height) / Iso.COS
	if flash_time > 0.0:
		flash_time -= dt
		sprite.set_flash(flash_color, flash_amount if flash_time > 0.0 else 0.0)


func flash(color := Color.WHITE, seconds := 0.07) -> void:
	flash_color = color
	flash_time = seconds
	if sprite:
		sprite.set_flash(color, flash_amount)
