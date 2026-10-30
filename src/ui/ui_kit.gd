class_name UI
## The look of every menu and of the HUD: pixel fonts, on the same pixel grid as
## the game, in the mine's dark colours with the lamp's warm ones to mark what matters.

const INK := Color("f0e6cf")
const DIM := Color("9a8d7a")
const FAINT := Color("5e564c")
const ACCENT := Color("ffb347")
const FIRE := Color("ff7a24")
const RED := Color("e04a2a")
const GAS := Color("b6ff5a")
const PANEL := Color("14101a")
const PANEL_EDGE := Color("3a3038")
const SHADOW := Color("060408")
const BODY_SIZE := 8
const HEADING_SIZE := 14

static var _body: Font
static var _heading: Font
static var _theme: Theme


static func body_font() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/body.fnt")
	return _body


static func heading_font() -> Font:
	if _heading == null:
		_heading = load("res://assets/fonts/heading.fnt")
	return _heading


static func label(text: String, color := INK, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style(l, color, heading)
	return l


static func style(l: Label, color := INK, heading := false) -> void:
	l.add_theme_font_override("font", heading_font() if heading else body_font())
	l.add_theme_font_size_override("font_size", HEADING_SIZE if heading else BODY_SIZE)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("line_spacing", 1)


static func box(color := PANEL, edge := PANEL_EDGE, margin := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_content_margin_all(margin)
	s.anti_aliasing = false
	return s


static func panel(margin := 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(PANEL, PANEL_EDGE, margin))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A button of the mine's: bright and arrowed when it's the one chosen.
static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", body_font())
	b.add_theme_font_size_override("font_size", BODY_SIZE)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", FAINT)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.set_content_margin_all(2)
	flat.content_margin_left = 8
	flat.content_margin_right = 8
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("disabled", flat)
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color("2a1f22")
	lit.border_color = ACCENT
	lit.border_width_left = 2
	lit.set_content_margin_all(2)
	lit.content_margin_left = 8
	lit.content_margin_right = 8
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus()
	)
	b.focus_entered.connect(func() -> void: Audio.play("tick", -10.0))
	b.pressed.connect(func() -> void: Audio.play("accept", -5.0))
	return b


## A column of buttons in order, wired so the sticks and the arrows go through them.
static func link_focus(buttons: Array) -> void:
	for i in buttons.size():
		var b: Control = buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[wrapi(i - 1, 0, buttons.size())])
		b.focus_neighbor_bottom = b.get_path_to(buttons[wrapi(i + 1, 0, buttons.size())])


static func center_in(parent: Control, child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.add_child(child)
	return c


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
