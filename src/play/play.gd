extends Node
## A shift down the mine: one level (World) after another, the HUD over them, and
## between them the cage, and what's found in it.

var world: World
var hud: Hud
var layer: CanvasLayer
var _pause: PauseMenu
var _touch: Control
var _skip := false
var _ui: Control


func open(args := {}) -> void:
	Game.new_run(int(args.get("mode", Run.NORMAL)), int(args.get("seed", -1)))
	if Game.runs_played <= 1 and Game.start_level == 0 and not Game.autoplay:
		await _briefing()
	_start_level()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	_pause = PauseMenu.new()
	_pause.visible = false
	ui.add_child(_pause)
	_ui = ui
	_on_device(Inputs.device)
	Inputs.device_changed.connect(_on_device)
	Inputs.pad_lost.connect(_on_pad_lost)


## The sticks under the thumbs are there for as long as it's played by touch: a tap
## on a Deck's screen brings them up, the first push of a real stick takes them away.
func _on_device(device: Inputs.Device) -> void:
	if device == Inputs.Device.TOUCH and _touch == null:
		_touch = TouchSticks.new()
		_ui.add_child(_touch)
	if _touch:
		_touch.visible = device == Inputs.Device.TOUCH


## The controller's gone: the mine waits till it's back.
func _on_pad_lost() -> void:
	if is_instance_valid(world) and not get_tree().paused and not world.finished and not world.player.dead:
		_pause.open()


## The first time down: what this is all about, a line at a time, skippable.
func _briefing() -> void:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(card)
	var bg := ColorRect.new()
	bg.color = Color(0.0235, 0.0196, 0.0314)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(300, 0)
	UI.center_in(card, column)
	var lines := [
		"The night shift at the Hallow Seam didn't come up.",
		"Nor did the men sent down after them. The Company says it was firedamp, and has offered money to anyone who'll go and see.",
		"You have a bow, some blasting powder, and the only lamp they could spare.",
	]
	for line: String in lines:
		var l := UI.label(line, UI.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visible_ratio = 0.0
		column.add_child(l)
		var t := create_tween()
		t.tween_property(l, "visible_ratio", 1.0, 0.03 * line.length())
		_skip = false
		var waited := 0.0
		while waited < 0.03 * line.length() + 1.2 and not _skip:
			await get_tree().process_frame
			waited += get_process_delta_time()
		t.kill()
		l.visible_ratio = 1.0
	var hint := UI.label("%s to go down" % Inputs.prompt("accept"), UI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	_skip = false
	while not _skip:
		await get_tree().process_frame
	card.queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("fire") or event.is_action_pressed("pause"):
		_skip = true


func _start_level() -> void:
	if world:
		world.queue_free()
		await world.tree_exited
	world = World.new()
	world.setup(Game.run)
	add_child(world)
	move_child(world, 0)
	world.exit_reached.connect(_on_exit_reached)
	world.player_dead.connect(_on_player_dead)
	world.boss_dead.connect(_on_boss_dead)
	hud.attach(world)
	var run := Game.run
	var depth: Dictionary = run.depth()
	if Game.autoplay:
		print("LEVEL %d (%s %d%s) run time %.0f s, score %d, wicks %d, kills %d, perks %s" % [run.level_index, depth.id, int(run.level().stage), " BOSS" if run.level().boss else "", run.time, run.score, run.wicks, run.kills, ",".join(run.perks.keys())])
	if run.level().boss:
		hud.banner(depth.boss_name, depth.boss_title, 3.2)
	elif int(run.level().stage) == 0:
		hud.banner(depth.name, depth.flavour, 3.4)
	else:
		hud.banner("%s %d" % [depth.name, int(run.level().stage) + 1], "", 1.8)
	Audio.play_music(_music_for(run), 1.2)
	Audio.play_ambience("ambient_mine", -14.0)
	Audio.muffle(0.0)
	Audio.play("cage_arrive", -3.0)
	if run.level_index == 0 and not Game.autoplay:
		_teach()


func _music_for(run: Run) -> String:
	if run.level().boss:
		return "final" if run.is_last_level() else "boss"
	return "mine" if int(run.level().depth) < 2 else "deep"


## The first level says how it's played, a line at a time.
func _teach() -> void:
	var lines := [
		["%s to walk, %s to shoot" % [Inputs.prompt("move"), Inputs.prompt("fire")], 5.0],
		["%s to roll out of the way" % Inputs.prompt("roll"), 5.0],
		["%s to change stance: Demolition blows up walls, kegs and gas" % Inputs.prompt("stance"), 6.0],
		["Every hit takes a wick off the lamp. Kill it all and the way down opens", 6.0],
	]
	for line: Array in lines:
		if world == null or Game.run.level_index != 0:
			return
		hud.set_prompt(line[0])
		await get_tree().create_timer(line[1], false).timeout
		if not is_instance_valid(hud):
			return
	hud.set_prompt("")


func _on_exit_reached() -> void:
	hud.set_prompt("")
	await get_tree().create_timer(0.5, false).timeout
	if Game.run.is_last_level():
		_win()
		return
	_pick_perk()


func _pick_perk() -> void:
	hud.clear_banner()
	var run := Game.run
	var pick := PerkPick.new()
	hud.add_child(pick)
	pick.choose(Perks.offer(run.perks, run.rng), func(perk: String) -> void:
		run.add_perk(perk)
		pick.queue_free()
		_next_level()
	)
	get_tree().paused = true
	Audio.muffle(0.6)


func _next_level() -> void:
	get_tree().paused = false
	Game.run.advance()
	Audio.muffle(0.0)
	_start_level()


func _on_boss_dead(_boss: Enemy) -> void:
	if Game.run.is_last_level():
		# The last of it. The way out is up, and it's all coming down.
		hud.banner("It is lit", "", 3.0)
	else:
		hud.banner("Put to rest", "", 2.4)


func _on_player_dead() -> void:
	var run := Game.run
	var place := Game.record_run(run, false)
	Audio.stop_music(1.5)
	Audio.muffle(0.8)
	Audio.play("death_sting", -2.0)
	Audio.stop_ambience()
	hud.clear_banner()
	var over := GameOver.new()
	hud.add_child(over)
	over.show_for(run, place)
	get_tree().paused = true


func _win() -> void:
	var place := Game.record_run(Game.run, true)
	Audio.stop_ambience()
	Game.main.show_screen("ending", {"place": place}, 1.2)


## For the screenshots: `--show=perk`, `pause`, `over`.
func debug_show(what: String) -> void:
	match what:
		"perk":
			Game.autoplay = false
			_pick_perk()
		"pause":
			_pause.open()
		"over":
			Game.autoplay = false
			Game.run.score = 12840
			Game.run.kills = 182
			_on_player_dead()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and world and is_instance_valid(world) and not world.finished and not world.player.dead:
		if not get_tree().paused:
			_pause.open()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and world and not get_tree().paused and not Game.autoplay:
		if not world.finished and not world.player.dead:
			_pause.open()
