class_name GameCamera
extends Camera3D
## The original game's camera, 53 degrees down and with no perspective, looking
## where the ranger is looking. It moves in whole pixels, so nothing shimmers.

var world: World
var focus := Vector2.ZERO
var target := Vector2.ZERO
var bounds := Rect2()
var trauma := 0.0
var _shake_time := 0.0
## Where it is on the plane of the floor, in pixels.
var at := Vector2.ZERO


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	near = 1.0
	far = 1600.0
	rotation_degrees = Vector3(Iso.PITCH, 0.0, 0.0)
	keep_aspect = Camera3D.KEEP_HEIGHT
	current = true


func jump_to(p: Vector2) -> void:
	target = p
	focus = p
	_place()


func kick(amount: float) -> void:
	trauma = minf(trauma + amount * float(Game.settings.shake), 1.0)
	Inputs.rumble(amount)


func _process(delta: float) -> void:
	focus = focus.lerp(target, 1.0 - exp(-delta * 7.0))
	_shake_time += delta
	trauma = maxf(trauma - delta * 1.9, 0.0)
	_place()


func _place() -> void:
	var size_px := get_viewport().get_visible_rect().size
	size = size_px.y
	var view := Vector2(size_px.x, size_px.y)
	var c := focus
	# Not past the edges of the mine, unless the mine is smaller than the screen.
	if bounds.size.x > view.x:
		c.x = clampf(c.x, bounds.position.x + view.x * 0.5, bounds.end.x - view.x * 0.5)
	else:
		c.x = bounds.get_center().x
	if bounds.size.y > view.y:
		c.y = clampf(c.y, bounds.position.y + view.y * 0.5, bounds.end.y - view.y * 0.5)
	else:
		c.y = bounds.get_center().y
	var shake := trauma * trauma * 9.0
	var offset := Vector2(sin(_shake_time * 67.0) + sin(_shake_time * 41.0), cos(_shake_time * 59.0) + cos(_shake_time * 31.0)) * 0.5 * shake
	at = (c + offset).round()
	var back := Vector3(0.0, Iso.SIN, Iso.COS)
	position = Iso.at(at) + back * 700.0
	# A window an odd number of pixels across would put the pixels between the texels.
	h_offset = 0.5 if int(size_px.x) % 2 == 1 else 0.0
	v_offset = 0.5 if int(size_px.y) % 2 == 1 else 0.0


## Where the point `p` on the floor, `h` up, is on the screen.
func to_screen(p: Vector2, h := 0.0) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	return Vector2(p.x - at.x + view.x * 0.5, p.y - h - at.y + view.y * 0.5)


## The point on the floor under this place on the screen (`h` up from it).
func to_floor(screen: Vector2, h := 0.0) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	return Vector2(screen.x + at.x - view.x * 0.5, screen.y + h + at.y - view.y * 0.5)
