extends Node
## `--pad-log`: writes what the game makes of its controls, four times a second, for
## tools/test_deck.py to read while it works a virtual controller from outside.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(_log)
	add_child(timer)
	timer.start()


func _log() -> void:
	var main: Node = get_parent()
	var pads := PackedStringArray()
	for pad in Input.get_connected_joypads():
		pads.append(Input.get_joy_name(pad))
	var state := {
		"screen": main.screen_name,
		"pads": pads,
		"device": Inputs.Device.keys()[Inputs.device],
		"deck": Inputs.deck,
		"paused": get_tree().paused,
		"window": get_window().size,
		"mode": get_window().mode,
		"game": get_viewport().get_visible_rect().size,
		"scale": get_window().get_final_transform().x.x,
		"focus": "",
		"prompt": Inputs.prompt("stance"),
	}
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Button:
		state.focus = focus.text
	if main.screen_name == "play" and is_instance_valid(main.screen.world) and main.screen.world.player:
		var world: World = main.screen.world
		var player: Player = world.player
		state.merge({
			"x": snappedf(player.pos.x, 0.1),
			"y": snappedf(player.pos.y, 0.1),
			"aim_x": snappedf(player.aim.x, 0.01),
			"aim_y": snappedf(player.aim.y, 0.01),
			"stance": player.stance,
			"firing": player.firing,
			"rolled": player.roll_cooldown > 0.0,
			"powder": world.run.powder,
			"wicks": world.run.wicks,
		})
	print("PAD ", JSON.stringify(state))
