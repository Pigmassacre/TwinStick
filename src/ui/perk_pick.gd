class_name PerkPick
extends Control
## Three things found in the cage on the way down; take one.

var _callback: Callable
var _cards: Array[Button] = []
var _ids: Array = []
var _opened_at := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func choose(ids: Array, callback: Callable) -> void:
	_ids = ids
	_callback = callback
	_opened_at = Time.get_ticks_msec()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.016, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	UI.center_in(self, column)
	var title := UI.label("In the cage, on the way down", UI.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	var icons: Texture2D = load("res://assets/sprites/perk_icons.png")
	for i in ids.size():
		var id: String = ids[i]
		var card := _card(id, icons)
		row.add_child(card)
		_cards.append(card)
		card.pressed.connect(_pick.bind(id))
	for i in _cards.size():
		_cards[i].focus_neighbor_left = _cards[i].get_path_to(_cards[wrapi(i - 1, 0, _cards.size())])
		_cards[i].focus_neighbor_right = _cards[i].get_path_to(_cards[wrapi(i + 1, 0, _cards.size())])
	var run := Game.run
	var held := PackedStringArray()
	for id: String in run.perks:
		held.append(Perks.ALL[id].name + (" x%d" % run.count(id) if run.count(id) > 1 else ""))
	if not held.is_empty():
		var so_far := UI.label(", ".join(held), UI.FAINT)
		so_far.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		so_far.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		so_far.custom_minimum_size = Vector2(340, 0)
		column.add_child(so_far)
	if not _cards.is_empty():
		_cards[0].grab_focus()
	if Game.autoplay:
		get_tree().create_timer(0.1, true, false, true).timeout.connect(func() -> void: _pick(ids[Game.run.rng.randi() % ids.size()]))


func _card(id: String, icons: Texture2D) -> Button:
	var def: Dictionary = Perks.ALL[id]
	var b := UI.button("")
	b.custom_minimum_size = Vector2(110, 84)
	var plain := UI.box(UI.PANEL, UI.PANEL_EDGE, 4)
	var lit := UI.box(Color("2a1f22"), UI.ACCENT, 4)
	b.add_theme_stylebox_override("normal", plain)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", lit)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 5
	inner.offset_right = -5
	inner.offset_top = 5
	inner.offset_bottom = -4
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = icons
	var frame: int = def.icon
	atlas.region = Rect2((frame % 8) * 16, (frame / 8) * 16, 16, 16)
	icon.texture = atlas
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(16, 18)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon)
	var name_label := UI.label(def.name, UI.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_label)
	var text := UI.label(def.text, UI.DIM)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(text)
	return b


func _pick(id: String) -> void:
	# Whoever was still mashing the roll button doesn't get to choose by accident.
	if Time.get_ticks_msec() - _opened_at < 450 and not Game.autoplay:
		return
	if _callback.is_valid():
		var callback := _callback
		_callback = Callable()
		Audio.play("perk", -3.0)
		callback.call(id)
