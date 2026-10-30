extends MenuScreen
## The board: the best shifts.


func _ready() -> void:
	build("THE BOARD")
	if Game.high_scores.is_empty():
		var l := UI.label("Nobody has been down yet.", UI.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(l)
		return
	var levels := Depths.levels()
	for i in Game.high_scores.size():
		var e: Dictionary = Game.high_scores[i]
		var level: Dictionary = levels[clampi(int(e.level), 0, levels.size() - 1)]
		var where: String = "Got out alive" if e.won else String(Depths.LIST[level.depth].name)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		body.add_child(row)
		var colour := UI.GAS if e.won else UI.INK
		var place := UI.label("%2d" % (i + 1), UI.FAINT)
		place.custom_minimum_size = Vector2(14, 0)
		row.add_child(place)
		var score := UI.label("%d" % int(e.score), colour)
		score.custom_minimum_size = Vector2(56, 0)
		row.add_child(score)
		var at := UI.label(where + (" (hard)" if e.get("hard", false) else ""), UI.DIM)
		at.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(at)
		row.add_child(UI.label(UI.format_time(float(e.time)), UI.FAINT))
		row.add_child(UI.label(String(e.date), UI.FAINT))
	if not Game.daily.is_empty() and Game.daily.get("date", "") == Time.get_date_string_from_system():
		var daily := UI.label("Today's Daily Shift: %d, in %d tries" % [int(Game.daily.best), int(Game.daily.tries)], UI.ACCENT)
		daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(daily)
