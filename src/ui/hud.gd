class_name Hud
extends Control
## On the screen while playing: the portrait and the lamp's wicks, the stances
## and the powder, the score and streak, the boss's health, words over things.

var world: World
var _portrait: TextureRect
var _wicks: HBoxContainer
var _stance_aim: TextureRect
var _stance_demolition: TextureRect
var _stance_frame: ColorRect
var _powder: Label
var _score: Label
var _streak: Label
var _depth: Label
var _boss_bar: ColorRect
var _boss_back: ColorRect
var _boss_name: Label
var _exit_arrow: Label
var _pops: Array[Dictionary] = []
var _banner: Label
var _banner2: Label
var _banner_time := 0.0
var _shown_score := 0
var _boss_shown := 1.0
var _wick_textures: Array[Texture2D] = []
var _prompt: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sheet: Texture2D = load("res://assets/sprites/wick.png")
	for i in 2:
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = Rect2(i * 8, 0, 8, 8)
		_wick_textures.append(a)
	var top := HBoxContainer.new()
	top.position = Vector2(4, 3)
	top.add_theme_constant_override("separation", 3)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_portrait = _icon("res://assets/sprites/portrait.png")
	top.add_child(_portrait)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(column)
	_wicks = HBoxContainer.new()
	_wicks.add_theme_constant_override("separation", 0)
	_wicks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_wicks)
	var stances := HBoxContainer.new()
	stances.add_theme_constant_override("separation", 2)
	stances.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stances)
	_stance_aim = _icon("res://assets/sprites/stance_aim.png")
	stances.add_child(_stance_aim)
	_stance_demolition = _icon("res://assets/sprites/stance_demolition.png")
	stances.add_child(_stance_demolition)
	_powder = UI.label("0", UI.ACCENT)
	stances.add_child(_powder)
	_score = UI.label("0", UI.INK)
	_score.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_score.offset_left = -120
	_score.offset_right = -4
	_score.offset_top = 3
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score)
	_streak = UI.label("", UI.ACCENT)
	_streak.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_streak.offset_left = -120
	_streak.offset_right = -4
	_streak.offset_top = 13
	_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_streak)
	_depth = UI.label("", UI.FAINT)
	_depth.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_depth.offset_left = 4
	_depth.offset_top = -13
	_depth.offset_right = 200
	_depth.offset_bottom = -3
	add_child(_depth)
	_prompt = UI.label("", UI.DIM)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -190
	_prompt.offset_right = 190
	_prompt.offset_top = -30
	_prompt.offset_bottom = -20
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	_boss_back = ColorRect.new()
	_boss_back.color = Color("0a0810")
	_boss_back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_back.offset_left = -100
	_boss_back.offset_right = 100
	_boss_back.offset_top = -12
	_boss_back.offset_bottom = -6
	_boss_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_back.visible = false
	add_child(_boss_back)
	_boss_bar = ColorRect.new()
	_boss_bar.color = UI.RED
	_boss_bar.position = Vector2(1, 1)
	_boss_bar.size = Vector2(198, 4)
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_back.add_child(_boss_bar)
	_boss_name = UI.label("", UI.INK)
	_boss_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_name.offset_left = -100
	_boss_name.offset_right = 100
	_boss_name.offset_top = -23
	_boss_name.offset_bottom = -13
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.visible = false
	add_child(_boss_name)
	_banner = UI.label("", UI.INK, true)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -200
	_banner.offset_right = 200
	_banner.offset_top = -44
	_banner.offset_bottom = -26
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	add_child(_banner)
	_banner2 = UI.label("", UI.DIM)
	_banner2.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner2.offset_left = -200
	_banner2.offset_right = 200
	_banner2.offset_top = -26
	_banner2.offset_bottom = -14
	_banner2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner2.visible = false
	add_child(_banner2)
	_exit_arrow = UI.label("v", UI.ACCENT, true)
	_exit_arrow.visible = false
	add_child(_exit_arrow)


## A picture at its own size, pixel for pixel, however tall its row is.
func _icon(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.stretch_mode = TextureRect.STRETCH_KEEP
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func attach(the_world: World) -> void:
	world = the_world
	world.hud_changed.connect(refresh)
	world.said.connect(pop)
	world.scored.connect(_score_pop)
	world.boss_appeared.connect(_on_boss)
	world.boss_dead.connect(func(_b: Enemy) -> void:
		_boss_back.visible = false
		_boss_name.visible = false
	)
	world.level_cleared.connect(func() -> void:
		banner("The way down is open", "Get to the shaft")
	)
	if world.boss:
		_on_boss(world.boss)
	var run := world.run
	_depth.text = "%s  %d-%d" % [run.depth().name, int(run.level().depth) + 1, int(run.level().stage) + 1]
	_depth.visible = not run.level().boss
	refresh()


func _on_boss(boss: Enemy) -> void:
	_boss_back.visible = true
	_boss_name.visible = true
	_boss_name.text = boss.def.name
	_boss_shown = 1.0


func refresh() -> void:
	if world == null:
		return
	var run := world.run
	while _wicks.get_child_count() < run.max_wicks:
		var t := TextureRect.new()
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wicks.add_child(t)
	for i in _wicks.get_child_count():
		var t: TextureRect = _wicks.get_child(i)
		t.texture = _wick_textures[0 if i < run.wicks else 1]
		t.modulate = Color.WHITE
	var aiming := world.player == null or world.player.stance == Player.AIM
	_stance_aim.modulate = Color.WHITE if aiming else Color(0.35, 0.35, 0.4)
	_stance_demolition.modulate = Color.WHITE if not aiming else Color(0.35, 0.35, 0.4)
	_powder.text = "%d" % run.powder
	_powder.add_theme_color_override("font_color", UI.ACCENT if run.powder > 0 else UI.RED)
	_streak.text = "x%d" % world.streak if world.streak > 1 else ""


func pop(text: String, at: Vector2, color := Color.WHITE) -> void:
	if world == null or world.cam == null:
		return
	var l := UI.label(text, color)
	add_child(l)
	# Long ones are for reading.
	_pops.append({"label": l, "at": at, "h": 18.0, "time": clampf(text.length() * 0.09, 1.0, 3.5)})


func _score_pop(amount: int, at: Vector2) -> void:
	var l := UI.label("%d" % amount, UI.DIM)
	add_child(l)
	_pops.append({"label": l, "at": at, "h": 14.0, "time": 0.6})


func banner(top: String, bottom := "", seconds := 2.6) -> void:
	_banner.text = top.to_upper()
	_banner.visible = true
	_banner2.text = bottom
	_banner2.visible = bottom != ""
	_banner_time = seconds


func clear_banner() -> void:
	_banner_time = 0.0
	_banner.visible = false
	_banner2.visible = false


func set_prompt(text: String) -> void:
	_prompt.text = text


func _process(delta: float) -> void:
	if world == null:
		return
	var run := world.run
	_shown_score = int(move_toward(_shown_score, run.score, maxf(delta * 2000.0, absf(run.score - _shown_score) * delta * 6.0)))
	_score.text = "%d" % _shown_score
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			_banner.visible = false
			_banner2.visible = false
	var i := _pops.size() - 1
	while i >= 0:
		var p := _pops[i]
		p.time -= delta
		p.h += delta * 18.0
		if p.time <= 0.0:
			p.label.queue_free()
			_pops.remove_at(i)
		else:
			var s: Vector2 = world.cam.to_screen(p.at, p.h)
			var l: Label = p.label
			l.position = (s - Vector2(l.size.x * 0.5, 4.0)).round()
			l.visible = p.time > 0.12 or int(p.time * 40.0) % 2 == 0
		i -= 1
	if world.boss:
		var share := clampf(world.boss.hp / world.boss.max_hp, 0.0, 1.0)
		_boss_shown = move_toward(_boss_shown, share, delta * 0.6)
		_boss_bar.size.x = round(198.0 * _boss_shown)
	queue_redraw()
	# Where the way down is, once it's open.
	_exit_arrow.visible = false
	if world.exit_open and not world.finished:
		var view := get_viewport_rect().size
		var at: Vector2 = world.cam.to_screen(Iso.cell_center(world.map.exit_cell), 0.0)
		var margin := 14.0
		var clamped := Vector2(clampf(at.x, margin, view.x - margin), clampf(at.y, margin + 12.0, view.y - margin))
		_exit_arrow.visible = int(world.time * 3.0) % 2 == 0
		_exit_arrow.text = "!"
		_exit_arrow.position = (clamped - Vector2(4.0, 22.0 - sin(world.time * 6.0) * 2.0)).round()


func _draw() -> void:
	if world == null or world.player == null or world.player.dead:
		return
	var view := get_viewport_rect().size
	# Where the bow is pointing, for those without a crosshair.
	if Inputs.device != Inputs.Device.MOUSE and not Game.autoplay:
		var demolition: bool = world.player.stance == Player.DEMOLITION
		var colour := UI.ACCENT if demolition else UI.INK
		# A dot; and in Demolition, a dotted line, for what's about to cost powder.
		var dots := 5 if demolition else 1
		for i in dots:
			var tip: Vector2 = world.cam.to_screen(world.player.pos + world.player.aim * (22.0 + i * 11.0), Balance.ARROW_HEIGHT)
			draw_rect(Rect2(tip.round() - Vector2.ONE, Vector2(2, 2)), colour)
	# The last few, when they've gone quiet: little marks at the edge of the screen.
	if world.exit_open or world.boss:
		return
	var left := 0
	for e: Enemy in world.enemies:
		if e.alive and e.counted and not e.minion:
			left += 1
	if left == 0 or left > 3:
		return
	for e: Enemy in world.enemies:
		if not e.alive or not e.counted or e.minion:
			continue
		var at: Vector2 = world.cam.to_screen(e.pos, 8.0)
		if Rect2(Vector2.ZERO, view).has_point(at):
			continue
		var edge := Vector2(clampf(at.x, 4.0, view.x - 6.0), clampf(at.y, 4.0, view.y - 6.0))
		if int(world.time * 4.0) % 2 == 0:
			draw_rect(Rect2(edge.round(), Vector2(3, 3)), UI.RED)
