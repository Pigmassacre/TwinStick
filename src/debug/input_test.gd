extends Node
## `--input-test`: plays the controls by sending real input events, and checks the
## ranger did what they say: walks, aims at the pointer, shoots, rolls, changes
## stance, with the mouse, then with the pad's events. Quits with 1 on a failure.

var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _check(what: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _click(button: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = get_viewport().get_mouse_position()
	Input.parse_input_event(e)


func _pad_button(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


func _pad_axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _run() -> void:
	await _wait(1.5)
	var main: Node = get_parent()
	var world: World = main.screen.world
	var player: Player = world.player
	player.autopilot = null
	world.freeze_for(0.0)
	for e in world.enemies:
		e.awake = false
		e.alive = false
	world._reap_enemies()
	# The pointer, in the window's pixels, should land where the game thinks it is, in its own.
	var window_size := get_window().size
	var game_size := get_viewport().get_visible_rect().size
	print("window ", window_size, ", game ", game_size, ", final transform ", get_window().get_final_transform(), ", stretch ", get_window().content_scale_stretch, " aspect ", get_window().content_scale_aspect, " size ", get_window().content_scale_size)
	var scale_by := float(window_size.x) / game_size.x
	var game_scale := floorf(minf(window_size.x / 384.0, window_size.y / 216.0))
	_check("the scale is a whole number (%.3f)" % scale_by, absf(scale_by - game_scale) < 0.02)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20, 0)
	motion.position = Vector2(window_size.x * 0.75, window_size.y * 0.5)
	Input.parse_input_event(motion)
	await _wait(0.1)
	_check("device is the mouse", Inputs.device == Inputs.Device.MOUSE)
	var before := player.pos
	_key(KEY_D, true)
	await _wait(0.5)
	_key(KEY_D, false)
	_check("D walks right (%.0f px)" % (player.pos.x - before.x), player.pos.x - before.x > 8.0)
	before = player.pos
	_key(KEY_A, true)
	await _wait(0.4)
	_key(KEY_A, false)
	_check("A walks left", player.pos.x < before.x)
	var want: Vector2 = world.cam.to_floor(get_viewport().get_mouse_position(), Balance.ARROW_HEIGHT) - player.pos
	_check("aims toward the pointer (%s, %s)" % [player.aim, want.normalized()], player.aim.dot(want.normalized()) > 0.9)
	_click(MOUSE_BUTTON_LEFT, true)
	await _wait(0.25)
	_check("left click looses arrows", player.firing and player.fire_cooldown > -0.1)
	_click(MOUSE_BUTTON_LEFT, false)
	await _wait(0.2)
	_check("demolition starts off", player.stance == Player.AIM)
	_click(MOUSE_BUTTON_RIGHT, true)
	await _wait(0.1)
	_click(MOUSE_BUTTON_RIGHT, false)
	_check("right click changes stance", player.stance == Player.DEMOLITION)
	var powder: int = world.run.powder
	_click(MOUSE_BUTTON_LEFT, true)
	await _wait(0.15)
	_click(MOUSE_BUTTON_LEFT, false)
	_check("demolition uses powder", world.run.powder < powder)
	await _wait(0.8)
	_key(KEY_Q, true)
	await _wait(0.05)
	_key(KEY_Q, false)
	_check("Q changes it back", player.stance == Player.AIM)
	_key(KEY_SPACE, true)
	await _wait(0.05)
	_key(KEY_SPACE, false)
	_check("Space rolls", player.roll_time > 0.0 or player.roll_cooldown > 0.0)
	await _wait(1.0)
	# The arrow keys take over the aim.
	_key(KEY_LEFT, true)
	await _wait(0.2)
	_check("arrow keys aim and shoot (%s)" % player.aim, player.aim.x < -0.5 and player.firing)
	_key(KEY_LEFT, false)
	# The pad.
	_pad_axis(JOY_AXIS_LEFT_X, -1.0)
	before = player.pos
	await _wait(0.3)
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	_check("device is the pad", Inputs.device == Inputs.Device.PAD)
	_check("left stick walks", player.pos.x < before.x)
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	await _wait(0.05)
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, false)
	_check("LB changes stance", player.stance == Player.DEMOLITION)
	await _wait(0.05)
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	await _wait(0.05)
	_pad_button(JOY_BUTTON_LEFT_SHOULDER, false)
	# A tap on the screen brings up the on-screen sticks; a real stick sends them away.
	var tap := InputEventScreenTouch.new()
	tap.position = Vector2(100, 100)
	tap.pressed = true
	Input.parse_input_event(tap)
	await _wait(0.1)
	tap = tap.duplicate()
	tap.pressed = false
	Input.parse_input_event(tap)
	await _wait(0.1)
	_check("a tap means touch", Inputs.device == Inputs.Device.TOUCH)
	var sticks: Control = main.screen._touch
	_check("and the sticks come up", sticks != null and sticks.visible)
	_pad_axis(JOY_AXIS_LEFT_X, 1.0)
	await _wait(0.1)
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	_check("and a stick sends them away", Inputs.device == Inputs.Device.PAD and not sticks.visible)
	# Pause.
	_key(KEY_ESCAPE, true)
	await _wait(0.1)
	_key(KEY_ESCAPE, false)
	_check("Esc pauses", get_tree().paused)
	await _wait(0.1)
	# With no button chosen, the first press chooses one.
	get_viewport().gui_release_focus()
	_pad_button(JOY_BUTTON_DPAD_DOWN, true)
	await _wait(0.1)
	_pad_button(JOY_BUTTON_DPAD_DOWN, false)
	_check("the pad gets the focus back", get_viewport().gui_get_focus_owner() != null)
	await _wait(0.1)
	_key(KEY_ESCAPE, true)
	await _wait(0.1)
	_key(KEY_ESCAPE, false)
	_check("Esc unpauses", not get_tree().paused)
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
