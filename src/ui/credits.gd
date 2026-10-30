extends MenuScreen
## Who did what.


func _ready() -> void:
	build("CREDITS")
	var text := FileAccess.get_file_as_string("res://src/data/credits.txt")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var l := UI.label(text, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.add_child(l)
