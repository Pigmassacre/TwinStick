class_name OptionsPanel
extends Control
## The settings, in a column: for the title's Options and the pause menu's.

signal closed

var _rows: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	UI.center_in(self, column)
	var title := UI.label("OPTIONS", UI.ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_slider(column, "Music", "music", 0.1)
	_slider(column, "Sounds", "sounds", 0.1)
	_slider(column, "Screen shake", "shake", 0.25)
	_toggle(column, "Bright flashes", "flashes")
	_toggle(column, "Aim help (pad, keys, touch)", "aim_assist")
	if not OS.has_feature("web"):
		_toggle(column, "Full screen", "fullscreen")
	var back := UI.button("Back")
	back.pressed.connect(func() -> void: closed.emit())
	column.add_child(back)
	_rows.append(back)
	UI.link_focus(_rows)
	_rows[0].grab_focus()


func _slider(column: Control, text: String, key: String, step: float) -> void:
	var b := UI.button("")
	var show_value := func() -> void:
		var v: float = Game.settings[key]
		b.text = "%s   < %d%% >" % [text, roundi(v * 100.0)]
	show_value.call()
	var change := func(by: float) -> void:
		Game.settings[key] = clampf(snappedf(float(Game.settings[key]) + by, 0.01), 0.0, 1.0)
		Game.apply_settings()
		Game.save()
		show_value.call()
		Audio.play("tick", -6.0)
	b.pressed.connect(func() -> void:
		var v: float = Game.settings[key]
		Game.settings[key] = 0.0 if v >= 0.999 else v
		change.call(step)
	)
	b.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			change.call(-step)
			b.accept_event()
		elif event.is_action_pressed("ui_right"):
			change.call(step)
			b.accept_event()
	)
	column.add_child(b)
	_rows.append(b)


func _toggle(column: Control, text: String, key: String) -> void:
	var b := UI.button("")
	var show_value := func() -> void:
		b.text = "%s   %s" % [text, "On" if Game.settings[key] else "Off"]
	show_value.call()
	b.pressed.connect(func() -> void:
		Game.settings[key] = not Game.settings[key]
		Game.apply_settings()
		Game.save()
		show_value.call()
	)
	column.add_child(b)
	_rows.append(b)
