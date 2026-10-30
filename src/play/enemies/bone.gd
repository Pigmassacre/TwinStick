extends Enemy
## An archer from some earlier expedition. Stands off, takes careful aim (you can
## see the line of it), and doesn't miss where you were.

const AIMING := 1

var line: MeshInstance3D
var aim_dir := Vector2.RIGHT


func init() -> void:
	timer = randf_range(1.0, 2.0)
	anim = "walk"
	line = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.5, 1.0)
	line.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.25, 0.2)
	line.material_override = m
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.visible = false
	add_child(line)


func think(dt: float) -> void:
	timer -= dt
	if state == 0:
		anim = "walk"
		keep_range(dt, 90.0, 170.0)
		if timer <= 0.0 and sees_player():
			state = AIMING
			timer = 0.75
			anim = "idle"
			vel = Vector2.ZERO
			Audio.play("draw", -8.0)
	else:
		face_player()
		if timer > 0.2:
			aim_dir = dir_to_player()
		_show_line()
		if timer <= 0.0:
			state = 0
			timer = randf_range(1.6, 2.6)
			line.visible = false
			world.shots.enemy(pos, aim_dir, 240.0, Shots.ARROW)
			Audio.play("bow", -7.0, 0.8)


## The line it's aiming along, thin and red.
func _show_line() -> void:
	line.visible = int(timer * 30.0) % 2 == 0 or timer > 0.25
	var length := 220.0
	var hit := pos + aim_dir * length
	for i in range(1, 37):
		if world.map.wall_at(pos + aim_dir * (i * 6.0)):
			hit = pos + aim_dir * (i * 6.0)
			break
	var from := Iso.at(pos, 7.0) - position
	var to := Iso.at(hit, 7.0) - position
	var mid := (from + to) * 0.5
	line.position = mid
	var dir_3d := to - from
	var b := Basis()
	b.x = dir_3d
	b.y = Vector3(0.0, 0.6, 0.0)
	b.z = Vector3(0.0, 0.0, 0.5)
	line.basis = b


func die(kind := "arrow") -> void:
	if alive and world:
		world.fx.chips(pos, 8.0, 12, Color("dbce90"), 90.0, 2.0)
		Audio.play("bones", -4.0, randf_range(0.9, 1.1))
	super.die(kind)
