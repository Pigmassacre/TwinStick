class_name TouchSticks
extends Control
## Two sticks under the thumbs, for a phone: the left walks, the right aims and
## shoots, and the two buttons roll and change stance.

const STICK_RADIUS := 26.0

var _left_id := -1
var _right_id := -1
var _left_home := Vector2.ZERO
var _right_home := Vector2.ZERO
var _left_at := Vector2.ZERO
var _right_at := Vector2.ZERO
var _roll_rect := Rect2()
var _stance_rect := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	var view := get_viewport_rect().size
	_roll_rect = Rect2(view.x - 42, view.y - 86, 36, 18)
	_stance_rect = Rect2(view.x - 42, view.y - 108, 36, 18)
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if _roll_rect.has_point(p):
				Inputs.touch_roll = true
			elif _stance_rect.has_point(p):
				Inputs.touch_stance = true
			elif p.x < view.x * 0.5 and _left_id < 0:
				_left_id = event.index
				_left_home = p
				_left_at = p
			elif p.x >= view.x * 0.5 and _right_id < 0:
				_right_id = event.index
				_right_home = p
				_right_at = p
		else:
			Inputs.touch_roll = false
			Inputs.touch_stance = false
			if event.index == _left_id:
				_left_id = -1
				Inputs.touch_move = Vector2.ZERO
			elif event.index == _right_id:
				_right_id = -1
				Inputs.touch_aim = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _left_id:
			_left_at = event.position
			Inputs.touch_move = ((_left_at - _left_home) / STICK_RADIUS).limit_length(1.0)
		elif event.index == _right_id:
			_right_at = event.position
			Inputs.touch_aim = ((_right_at - _right_home) / STICK_RADIUS).limit_length(1.0)
		queue_redraw()


func _draw() -> void:
	var edge := Color(0.95, 0.9, 0.8, 0.35)
	if _left_id >= 0:
		draw_arc(_left_home, STICK_RADIUS, 0.0, TAU, 24, edge, 1.0, false)
		draw_circle(_left_at, 7.0, edge)
	if _right_id >= 0:
		draw_arc(_right_home, STICK_RADIUS, 0.0, TAU, 24, edge, 1.0, false)
		draw_circle(_right_at, 7.0, edge)
	draw_rect(_roll_rect, edge, false)
	draw_rect(_stance_rect, edge, false)
	var font := UI.body_font()
	draw_string(font, _roll_rect.position + Vector2(9, 12), "Roll", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.BODY_SIZE, edge)
	draw_string(font, _stance_rect.position + Vector2(3, 12), "Stance", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.BODY_SIZE, edge)
