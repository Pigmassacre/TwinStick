extends Node
## Sets up the input actions in code, so they live in one readable place, and
## keeps track of what the player last played with, so the prompts can name the
## right button and the game knows how to aim.

enum Device { KEYBOARD, MOUSE, PAD, TOUCH }

signal device_changed(device: Device)

const KEYS := {
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"move_up": [KEY_W],
	"move_down": [KEY_S],
	"shoot_left": [KEY_LEFT],
	"shoot_right": [KEY_RIGHT],
	"shoot_up": [KEY_UP],
	"shoot_down": [KEY_DOWN],
	"fire": [],
	"stance": [KEY_Q, KEY_E],
	"roll": [KEY_SPACE, KEY_SHIFT],
	"pause": [KEY_ESCAPE, KEY_P],
}

const BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"stance": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_Y, JOY_BUTTON_X],
	"roll": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_A],
	"fire": [],
	"pause": [JOY_BUTTON_START, JOY_BUTTON_BACK],
}

## Action: [axis, direction]
const AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"roll": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}

const MOUSE := {
	"fire": [MOUSE_BUTTON_LEFT],
	"stance": [MOUSE_BUTTON_RIGHT],
}

var device := Device.MOUSE
## The pad's prompts: Xbox's letters, or PlayStation's shapes.
var playstation := false
## The last way the stick pointed, for firing with the trigger.
var last_pad_aim := Vector2.RIGHT
## What the on-screen sticks say, when played by finger (src/ui/touch_sticks.gd).
var touch_move := Vector2.ZERO
var touch_aim := Vector2.ZERO
var touch_roll := false
var touch_stance := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: Key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		for button: JoyButton in BUTTONS.get(action, []):
			var press := InputEventJoypadButton.new()
			press.button_index = button
			InputMap.action_add_event(action, press)
		if AXES.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = AXES[action][0]
			motion.axis_value = AXES[action][1]
			InputMap.action_add_event(action, motion)
		for mouse_button: MouseButton in MOUSE.get(action, []):
			var click := InputEventMouseButton.new()
			click.button_index = mouse_button
			InputMap.action_add_event(action, click)
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		InputMap.action_set_deadzone(action, 0.18)
	InputMap.action_set_deadzone("fire", 0.4)
	InputMap.action_set_deadzone("roll", 0.5)
	# The menus answer to a pad and WASD too.
	_add_ui("ui_accept", [JOY_BUTTON_A], [KEY_SPACE])
	_add_ui("ui_cancel", [JOY_BUTTON_B], [])
	_add_ui("ui_up", [JOY_BUTTON_DPAD_UP], [KEY_W], JOY_AXIS_LEFT_Y, -1.0)
	_add_ui("ui_down", [JOY_BUTTON_DPAD_DOWN], [KEY_S], JOY_AXIS_LEFT_Y, 1.0)
	_add_ui("ui_left", [JOY_BUTTON_DPAD_LEFT], [KEY_A], JOY_AXIS_LEFT_X, -1.0)
	_add_ui("ui_right", [JOY_BUTTON_DPAD_RIGHT], [KEY_D], JOY_AXIS_LEFT_X, 1.0)
	if DisplayServer.is_touchscreen_available() and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		device = Device.TOUCH


## Adds pad buttons, keys and a stick direction to a UI action.
func _add_ui(action: String, buttons: Array, keys: Array, axis := -1, direction := 0.0) -> void:
	for button: JoyButton in buttons:
		var press := InputEventJoypadButton.new()
		press.button_index = button
		InputMap.action_add_event(action, press)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if axis >= 0:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = direction
		InputMap.action_add_event(action, motion)


func _input(event: InputEvent) -> void:
	var now := device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		now = Device.TOUCH
	elif event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 1.0):
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			now = Device.MOUSE
	elif event is InputEventKey:
		# The arrows and WASD keep the mouse's aim until the arrows are what's shooting.
		if event.pressed and (event.physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]):
			now = Device.KEYBOARD
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		now = Device.PAD
		var pad_name := Input.get_joy_name(event.device).to_lower()
		playstation = pad_name.contains("ps") or pad_name.contains("dualsense") or pad_name.contains("dualshock") \
			or pad_name.contains("playstation") or pad_name.contains("sony")
	if now != device:
		device = now
		device_changed.emit(device)


## Where the ranger is walking, in a circle of length up to 1.
func move_vector() -> Vector2:
	if touch_move != Vector2.ZERO:
		return touch_move
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## The pad's right stick, with the original game's dead zone.
func pad_aim() -> Vector2:
	var best := Vector2.ZERO
	for pad in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		if v.length() > best.length():
			best = v
	if best.length() < Balance.AIM_DEADZONE:
		return Vector2.ZERO
	last_pad_aim = best.normalized()
	return last_pad_aim


## The arrow keys' direction, or nothing.
func key_aim() -> Vector2:
	var v := Vector2(Input.get_axis("shoot_left", "shoot_right"), Input.get_axis("shoot_up", "shoot_down"))
	return v.normalized() if v != Vector2.ZERO else Vector2.ZERO


## What to press for `action`, on what the player is playing with now.
func prompt(action: String) -> String:
	match device:
		Device.TOUCH:
			return {"fire": "right stick", "stance": "stance", "roll": "roll", "pause": "pause", "move": "left stick"}.get(action, "tap")
		Device.PAD:
			if playstation:
				return {"fire": "right stick", "stance": "L1", "roll": "R1", "pause": "Options", "move": "left stick", "accept": "Cross"}.get(action, "Cross")
			return {"fire": "right stick", "stance": "LB", "roll": "RB", "pause": "Start", "move": "left stick", "accept": "A"}.get(action, "A")
		Device.KEYBOARD:
			return {"fire": "arrow keys", "stance": "Q", "roll": "Space", "pause": "Esc", "move": "WASD", "accept": "Space"}.get(action, "Space")
	return {"fire": "left click", "stance": "right click", "roll": "Space", "pause": "Esc", "move": "WASD", "accept": "click"}.get(action, "Space")
