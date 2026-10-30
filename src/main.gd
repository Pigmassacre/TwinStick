extends Node
## The root: shows one screen at a time (the title, the game, the menus), fading
## through black between them.
##
## For testing without playing:
## `--screen=play` (or any screen's name) starts there, `--level=5` starts the
## run on that level of Depths.levels(), `--seed=3` fixes the seed, `--perks=twin,fire`
## hands those out, `--autoplay` has the game play itself (`--invincible` so it
## can't lose), `--speed=4` runs it faster, `--shots=1.5,4,9` saves a screenshot
## to shots/ at each of those seconds (of game time) and quits after the last,
## `--shot-name=x` names them, `--size=1280x720` sizes the window,
## `--quit-after=60` quits after so many seconds, and `--input-test` plays the
## controls by sending real input events (src/debug/input_test.gd).

const SCREENS := {
	"title": "res://src/ui/title.gd",
	"play": "res://src/play/play.gd",
	"options": "res://src/ui/options.gd",
	"help": "res://src/ui/help.gd",
	"scores": "res://src/ui/scores.gd",
	"ending": "res://src/ui/ending.gd",
	"credits": "res://src/ui/credits.gd",
}

const BASE_SIZE := Vector2(384, 216)

var screen: Node
var screen_name := ""
var _fade: ColorRect
var _busy := false
var _shot_name := ""
var _fitted_to := Vector2.ZERO
var _debug_show := ""
var _cursor: TextureRect
var _pointer_tex: Texture2D
var _crosshair_tex: Texture2D


func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.min_size = Vector2i(384, 216)
	_fit_window()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.0235, 0.0196, 0.0314, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	# The pointer is drawn in the game's own pixels, like everything else.
	_pointer_tex = load("res://assets/sprites/pointer.png")
	_crosshair_tex = load("res://assets/sprites/crosshair.png")
	_cursor = TextureRect.new()
	_cursor.texture = _pointer_tex
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_cursor)
	var first := "title"
	var quit_after := -1.0
	var shots := []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			first = arg.trim_prefix("--screen=")
		elif arg.begins_with("--level="):
			Game.start_level = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--seed="):
			Game.fixed_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--perks="):
			Game.start_perks = Array(arg.trim_prefix("--perks=").split(","))
		elif arg == "--autoplay":
			Game.autoplay = true
		elif arg == "--invincible":
			Game.autoplay_invincible = true
		elif arg.begins_with("--speed="):
			Game.test_speed = float(arg.trim_prefix("--speed="))
			Engine.time_scale = Game.test_speed
			Engine.max_physics_steps_per_frame = int(max(4.0, Game.test_speed * 2.0))
		elif arg.begins_with("--size="):
			var wh := arg.trim_prefix("--size=").split("x")
			get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		elif arg.begins_with("--shot-name="):
			_shot_name = arg.trim_prefix("--shot-name=")
		elif arg.begins_with("--shots="):
			shots = Array(arg.trim_prefix("--shots=").split(",")).map(func(t: String) -> float: return float(t))
		elif arg == "--input-test":
			Game.autoplay = true
			add_child(preload("res://src/debug/input_test.gd").new())
		elif arg.begins_with("--show="):
			_debug_show = arg.trim_prefix("--show=")
		elif arg.begins_with("--quit-after="):
			quit_after = float(arg.trim_prefix("--quit-after="))
	if Game.autoplay:
		print("seed ", Game.fixed_seed)
	show_screen(first)
	if _debug_show != "":
		get_tree().create_timer(0.6).timeout.connect(func() -> void: screen.debug_show(_debug_show))
	if not shots.is_empty():
		_take_shots(shots)
	if quit_after > 0.0:
		get_tree().create_timer(quit_after, true, false, true).timeout.connect(func() -> void:
			get_tree().quit())


## The game's pixels are always a whole number of the window's, however big the
## window is: at least 384 by 216 of them, and however many more fit.
func _fit_window() -> void:
	var root := get_tree().root
	var window := Vector2(root.size)
	if window == _fitted_to or window.x <= 0.0 or window.y <= 0.0:
		return
	_fitted_to = window
	var by := maxf(1.0, floorf(minf(window.x / BASE_SIZE.x, window.y / BASE_SIZE.y)))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(ceili(window.x / by), ceili(window.y / by))


func _take_shots(times: Array) -> void:
	# From the project, shots/ in it; from a build, wherever it can write.
	var folder := "res://shots" if OS.has_feature("editor") else "user://shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	# Kept out of the editor's imports (and so out of the builds).
	FileAccess.open(folder + "/.gdignore", FileAccess.WRITE)
	var clock := 0.0
	for t: float in times:
		while clock < t:
			await get_tree().process_frame
			clock += get_process_delta_time() / maxf(Engine.time_scale, 0.001) * Engine.time_scale
		await RenderingServer.frame_post_draw
		var name_part := _shot_name if _shot_name != "" else screen_name
		var path := folder + "/%s_%05.1f.png" % [name_part, t]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()


## Shows the screen by that name. Its `open(args)`, if it has one, is given `args`.
func show_screen(which: String, args := {}, fade := 0.0) -> void:
	if _busy:
		return
	_busy = true
	if fade > 0.0 and screen != null:
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(_fade, "color:a", 1.0, fade)
		await t.finished
	if screen:
		screen.queue_free()
		screen = null
	get_tree().paused = false
	Audio.stop_sounds()
	var script: Script = load(SCREENS[which])
	screen = script.new()
	screen_name = which
	add_child(screen)
	if screen.has_method("open"):
		screen.open(args)
	_busy = false
	if fade > 0.0:
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(_fade, "color:a", 0.0, fade)
	else:
		_fade.color.a = 0.0


func _process(_delta: float) -> void:
	_fit_window()
	var playing: bool = screen_name == "play" and not get_tree().paused and is_instance_valid(screen) and is_instance_valid(screen.world) and not screen.world.finished and not screen.world.player.dead
	_cursor.visible = Inputs.device == Inputs.Device.MOUSE or (not playing and Inputs.device == Inputs.Device.KEYBOARD)
	if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var at := get_viewport().get_mouse_position().round()
	if playing:
		_cursor.texture = _crosshair_tex
		_cursor.position = at - Vector2(5, 5)
		_cursor.modulate = UI.ACCENT if screen.world.player.stance == Player.DEMOLITION else Color.WHITE
	else:
		_cursor.texture = _pointer_tex
		_cursor.position = at
		_cursor.modulate = Color.WHITE


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11 or (event.physical_keycode == KEY_ENTER and event.alt_pressed):
			Game.toggle_fullscreen()
			get_viewport().set_input_as_handled()
