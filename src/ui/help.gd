extends MenuScreen
## How it's done: the controls, the two stances, the lamp, the gas.


func _ready() -> void:
	build("HOW IT'S DONE")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)
	_heading(left, "The ranger")
	_text(left, Inputs.controls_text())
	_heading(left, "The lamp")
	_text(left, "Each hit takes a wick off it, and it shines less far. No wicks, no lamp. While rolling, nothing can hit you.")
	_text(left, "What's in the dark sleeps until the lamp finds it, or a noise.")
	_stance(right, "stance_aim", "Aim", "Fast arrows that go through things.")
	_stance(right, "stance_demolition", "Demolition", "Dynamite on an arrow. Costs powder. Breaks walls, armour and kegs.")
	_heading(right, "Firedamp")
	_text(right, "The green gas does nothing until lit. Then all of it goes, and it will hurt you too.")
	_heading(right, "The way down")
	_text(right, "Kill it all and the shaft opens. A cracked wall has something behind it.")


func _heading(parent: Control, text: String) -> void:
	parent.add_child(UI.label(text, UI.ACCENT))


func _text(parent: Control, text: String) -> void:
	var l := UI.label(text, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(160, 0)
	parent.add_child(l)


func _stance(parent: Control, icon: String, title: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var t := TextureRect.new()
	t.texture = load("res://assets/sprites/%s.png" % icon)
	t.stretch_mode = TextureRect.STRETCH_KEEP
	row.add_child(t)
	row.add_child(UI.label(title, UI.ACCENT))
	_text(parent, text)
