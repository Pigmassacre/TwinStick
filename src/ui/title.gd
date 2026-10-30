extends Node
## The title: the ranger in a chamber of the mine, the lamp going, eyes out in
## the dark, and the way down.

var world: World
var _logo_frames: Array[Texture2D] = []
var _logo: TextureRect
var _clock := 0.0
var _first: Button


func _ready() -> void:
	var run := Run.new()
	run.start(Run.NORMAL, 20150511)
	world = World.new()
	world.attract = true
	world.setup(run)
	add_child(world)
	world.cam.bounds = Rect2(-10000, -10000, 20000, 20000)
	world.cam.jump_to(world.player.pos + Vector2(70.0, -24.0))
	world.cam.target = world.cam.focus
	world.warm_up()
	Audio.play_music("title", 1.5)
	Audio.heat = 0.5
	Audio.muffle(0.0)
	Audio.play_ambience("ambient_mine", -16.0)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	var sheet: Texture2D = load("res://assets/sprites/logo.png")
	var info: Dictionary = Sheets.ALL.logo
	for i in 4:
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = Rect2((i % int(info.cols)) * int(info.w), (i / int(info.cols)) * int(info.h), info.w, info.h)
		_logo_frames.append(a)
	_logo = TextureRect.new()
	_logo.texture = _logo_frames[0]
	_logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_logo.offset_left = -int(info.w) / 2
	_logo.offset_right = int(info.w) / 2
	_logo.offset_top = 2
	_logo.offset_bottom = 2 + int(info.h)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_logo)
	var tag := UI.label("You carry the only light in the mine.", UI.DIM)
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tag.offset_left = -130
	tag.offset_right = 130
	tag.offset_top = 56
	tag.offset_bottom = 68
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(tag)
	# The dark the menu stands in.
	var shade := ColorRect.new()
	shade.color = Color(0.0235, 0.0196, 0.0314, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	shade.offset_left = -136
	shade.offset_top = 70
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	column.offset_left = -128
	column.offset_right = -10
	column.offset_top = -112
	column.offset_bottom = -8
	column.alignment = BoxContainer.ALIGNMENT_END
	ui.add_child(column)
	var buttons: Array[Button] = []
	var add := func(text: String, what: Callable) -> Button:
		var b := UI.button(text)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(what)
		column.add_child(b)
		buttons.append(b)
		return b
	_first = add.call("Go down", func() -> void: _start(Run.NORMAL))
	if Game.wins > 0:
		add.call("Go down: the Hard Shift", func() -> void: _start(Run.HARD))
	add.call("The Daily Shift", func() -> void: _start(Run.DAILY, Game.daily_seed()))
	add.call("How it's done", func() -> void: Game.main.show_screen("help", {}, 0.25))
	add.call("The board", func() -> void: Game.main.show_screen("scores", {}, 0.25))
	add.call("Options", func() -> void: Game.main.show_screen("options", {}, 0.25))
	add.call("Credits", func() -> void: Game.main.show_screen("credits", {}, 0.25))
	if not OS.has_feature("web"):
		add.call("Quit", func() -> void: get_tree().quit())
	UI.link_focus(buttons)
	_first.grab_focus()
	var version := UI.label(Game.version_text(), UI.FAINT)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 4
	version.offset_right = 160
	version.offset_top = -12
	version.offset_bottom = -2
	ui.add_child(version)
	if Game.deepest > 0:
		var deepest := UI.label("Deepest: %s" % _level_name(Game.deepest), UI.FAINT)
		deepest.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		deepest.offset_left = 4
		deepest.offset_right = 200
		deepest.offset_top = -23
		deepest.offset_bottom = -13
		ui.add_child(deepest)


func _level_name(index: int) -> String:
	var levels := Depths.levels()
	var level: Dictionary = levels[clampi(index, 0, levels.size() - 1)]
	return String(Depths.LIST[level.depth].name)


func _process(delta: float) -> void:
	_clock += delta
	_logo.texture = _logo_frames[int(_clock * 7.0) % _logo_frames.size()]


func _start(mode: int, seed_value := -1) -> void:
	if not Game.seen_help:
		Game.seen_help = true
		Game.save()
	Audio.stop_ambience()
	Game.main.show_screen("play", {"mode": mode, "seed": seed_value}, 0.5)
