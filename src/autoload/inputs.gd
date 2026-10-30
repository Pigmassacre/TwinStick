extends Node
## Sets up the input actions in code, so they live in one readable place, and
## keeps track of what the player last played with, so the prompts can name the
## right button and the game knows how to aim.

enum Device { KEYBOARD, MOUSE, PAD, TOUCH }

signal device_changed(device: Device)
## A controller has gone away mid-game (out of battery, unplugged).
signal pad_lost

const KEYS := {
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"move_up": [KEY_W],
	"move_down": [KEY_S],
	"aim_left": [],
	"aim_right": [],
	"aim_up": [],
	"aim_down": [],
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
	"aim_left": [JOY_AXIS_RIGHT_X, -1.0],
	"aim_right": [JOY_AXIS_RIGHT_X, 1.0],
	"aim_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"roll": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}

const MOUSE := {
	"fire": [MOUSE_BUTTON_LEFT],
	"stance": [MOUSE_BUTTON_RIGHT],
}

var device := Device.MOUSE
## Running on a Steam Deck (or pretending to, with `--deck`).
var deck := _is_deck()
## The pad's prompts: Xbox's letters, or PlayStation's shapes.
var playstation := false
## The pad last used, for the rumble.
var last_pad := 0
var _rumble_until := 0
var _rumble_level := 0.0
var _pointer_seen := false
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
	for action in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		InputMap.action_set_deadzone(action, Balance.AIM_DEADZONE)
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
	# A Deck's controls are a pad, whatever was last touched.
	if deck:
		device = Device.PAD
	Input.joy_connection_changed.connect(_on_joy_connection)


## SteamOS says so when Steam starts the game; otherwise the board is Valve's (the LCD's, and the OLED's).
static func _is_deck() -> bool:
	if OS.get_cmdline_user_args().has("--deck") or OS.get_environment("SteamDeck") == "1":
		return true
	if OS.get_name() == "Linux":
		for file: String in ["/sys/devices/virtual/dmi/id/board_name", "/sys/devices/virtual/dmi/id/product_name"]:
			if FileAccess.file_exists(file) and FileAccess.get_file_as_string(file).strip_edges() in ["Jupiter", "Galileo"]:
				return true
	return false


func _on_joy_connection(_pad: int, connected: bool) -> void:
	if not connected and device == Device.PAD:
		pad_lost.emit()


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
		# A window that has just opened gets told where the pointer is: nobody has moved it.
		if event is InputEventMouseMotion and not _pointer_seen:
			_pointer_seen = true
		elif event.device != InputEvent.DEVICE_ID_EMULATION:
			now = Device.MOUSE
	elif event is InputEventKey:
		# The arrows and WASD keep the mouse's aim until the arrows are what's shooting.
		if event.pressed and (event.physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]):
			now = Device.KEYBOARD
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		now = Device.PAD
		last_pad = event.device
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


## The pad's right stick, with the original game's dead zone: its length is how far it's pushed.
func pad_aim() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")


## A shake of the pad, 0 to 1. A small one doesn't cut a big one short.
func rumble(amount: float) -> void:
	if device != Device.PAD or not Game.settings.rumble:
		return
	var now := Time.get_ticks_msec()
	if now < _rumble_until and amount <= _rumble_level:
		return
	var seconds := 0.06 + amount * 0.22
	_rumble_level = amount
	_rumble_until = now + int(seconds * 1000.0)
	Input.start_joy_vibration(last_pad, clampf(amount * 1.2, 0.0, 1.0), clampf(amount, 0.0, 1.0), seconds)


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
			if deck and not playstation:
				return {"fire": "right stick", "stance": "L1", "roll": "R1", "pause": "Menu", "move": "left stick", "accept": "A"}.get(action, "A")
			if playstation:
				return {"fire": "right stick", "stance": "L1", "roll": "R1", "pause": "Options", "move": "left stick", "accept": "Cross"}.get(action, "Cross")
			return {"fire": "right stick", "stance": "LB", "roll": "RB", "pause": "Start", "move": "left stick", "accept": "A"}.get(action, "A")
		Device.KEYBOARD:
			return {"fire": "arrow keys", "stance": "Q", "roll": "Space", "pause": "Esc", "move": "WASD", "accept": "Space"}.get(action, "Space")
	return {"fire": "left click", "stance": "right click", "roll": "Space", "pause": "Esc", "move": "WASD", "accept": "click"}.get(action, "Space")


## How it's played, in a line, on what the player is playing with now.
func controls_text() -> String:
	match device:
		Device.PAD:
			var move := prompt("move")
			return "%s walks, %s shoots, %s changes stance, %s rolls. In Demolition, push the stick all the way to throw." % [move[0].to_upper() + move.substr(1), prompt("fire"), prompt("stance"), prompt("roll")]
		Device.TOUCH:
			return "Left thumb walks, right thumb shoots. Stance and Roll are the buttons."
		Device.KEYBOARD:
			return "WASD walks, arrow keys shoot, Q changes stance, Space rolls."
	return "WASD walks, left click shoots, right click changes stance, Space rolls."
