extends MenuScreen
## Out alive: what happened, how it went, and a new shift to work.

const LINES := [
	"The seam went up behind the cage.",
	"You felt it through the floor before you heard it, and then the whole hill breathed out.",
	"The Company's man was waiting at the top with a ledger. He asked what you'd found down there.",
	"You blew out the lamp, and went home.",
]

var _place := -1
var _shown := 0
var _clock := 0.0
var _labels: Array[Label] = []
var _stats: Control


func open(args := {}) -> void:
	_place = int(args.get("place", -1))


func _ready() -> void:
	build("OUT")
	Audio.play_music("ending", 2.0)
	Audio.heat = 0.5
	Audio.muffle(0.0)
	back.text = "Up to the title"
	back.offset_left = -50
	back.offset_right = 50
	back.visible = false
	for line: String in LINES:
		var l := UI.label(line, UI.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visible = false
		body.add_child(l)
		_labels.append(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		body.add_child(gap)
	_stats = VBoxContainer.new()
	_stats.visible = false
	body.add_child(_stats)
	if Game.run == null:
		Game.new_run()
	var run := Game.run
	var score := UI.label("%d" % run.score, UI.ACCENT, true)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_child(score)
	var numbers := UI.label("%d killed   %d nuggets   %d walls blown   best streak x%d   %s" % [run.kills, run.nuggets, run.walls_blown, run.best_streak, UI.format_time(run.time)], UI.DIM)
	numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_child(numbers)
	if Game.wins == 1:
		var unlocked := UI.label("The Hard Shift is open.", UI.GAS)
		unlocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats.add_child(unlocked)
	var thanks := UI.label("Thank you for playing.", UI.FAINT)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_child(thanks)
	if Game.autoplay:
		print("WON: score ", run.score, " time ", int(run.time), " kills ", run.kills)
		get_tree().create_timer(1.0, true, false, true).timeout.connect(func() -> void: get_tree().quit())


func _process(delta: float) -> void:
	_clock += delta
	if _shown < _labels.size() and _clock > 1.0 + _shown * 3.0:
		_labels[_shown].visible = true
		_shown += 1
		Audio.play("tick", -8.0)
	elif _shown == _labels.size() and _clock > 1.0 + _shown * 3.0 and not _stats.visible:
		_stats.visible = true
		back.visible = true
		back.grab_focus()
