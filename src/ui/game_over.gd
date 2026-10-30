class_name GameOver
extends Control
## When the lamp goes out: how far it got, and whether to go back down.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_for(run: Run, place: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.016, 0.03, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	UI.center_in(self, column)
	var title := UI.label("THE LAMP WENT OUT", UI.RED, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var where := UI.label("In %s, at %s" % [run.depth().name, _level_text(run)], UI.DIM)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(where)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	column.add_child(spacer)
	var score := UI.label("%d" % run.score, UI.ACCENT, true)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(score)
	if place == 0 and Game.high_scores.size() > 1:
		var best := UI.label("Best shift yet", UI.GAS)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(best)
	elif place >= 0:
		var board := UI.label("No. %d on the board" % (place + 1), UI.DIM)
		board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(board)
	var stats := UI.label("%d killed   %d nuggets   %d walls blown   best streak x%d   %s" % [run.kills, run.nuggets, run.walls_blown, run.best_streak, UI.format_time(run.time)], UI.FAINT)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer2)
	var again := UI.button("Back down")
	again.pressed.connect(func() -> void:
		var mode := run.mode
		get_tree().paused = false
		Game.main.show_screen("play", {"mode": mode, "seed": Game.daily_seed() if mode == Run.DAILY else -1}, 0.3)
	)
	column.add_child(again)
	var out := UI.button("Up to the title")
	out.pressed.connect(func() -> void:
		get_tree().paused = false
		Game.main.show_screen("title", {}, 0.3)
	)
	column.add_child(out)
	UI.link_focus([again, out])
	again.grab_focus()
	if Game.autoplay:
		print("RUN OVER: level ", run.level_index, " score ", run.score, " time ", int(run.time), " kills ", run.kills)
		get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void: get_tree().quit())


static func _level_text(run: Run) -> String:
	if run.level().boss:
		return String(run.depth().boss_name)
	return "level %d-%d" % [int(run.level().depth) + 1, int(run.level().stage) + 1]
