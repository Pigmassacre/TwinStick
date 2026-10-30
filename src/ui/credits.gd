extends MenuScreen
## Who did what.


var _scroll: ScrollContainer


func _process(delta: float) -> void:
	# Back keeps the focus, so the sticks and the arrows do the scrolling.
	var by := Input.get_axis("ui_up", "ui_down") + Input.get_axis("aim_up", "aim_down")
	if by != 0.0:
		_scroll.scroll_vertical += int(by * 90.0 * delta + signf(by))


func _ready() -> void:
	build("CREDITS")
	var text := FileAccess.get_file_as_string("res://src/data/credits.txt")
	_scroll = ScrollContainer.new()
	var scroll := _scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var l := UI.label(text, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.add_child(l)
