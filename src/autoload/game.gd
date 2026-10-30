extends Node
## What lasts between games: the settings, the best runs, the shift just being
## played. Saved in user://firedamp.cfg.

signal settings_changed

const SAVE_PATH := "user://firedamp.cfg"
const HIGH_SCORES := 10

const DEFAULTS := {
	"music": 0.7,
	"sounds": 0.85,
	"shake": 1.0,
	"flashes": true,
	"fullscreen": false,
	"aim_assist": true,
}

var settings := DEFAULTS.duplicate()
## The best runs, best first: {"score", "level", "depth", "time", "won", "hard", "date"}.
var high_scores: Array = []
var runs_played := 0
## Runs that have got out alive; the first unlocks the Hard Shift.
var wins := 0
var deepest := 0
var seen_help := false
## The day's Daily Shift: {"date", "best", "tries"} (a new day starts it over).
var daily := {}

## The shift being played.
var run: Run
## The screen being shown (main.gd swaps them).
var main: Node

## For testing without playing: the game plays itself (`--autoplay`, src/debug/autopilot.gd).
var autoplay := false
var autoplay_invincible := false
## `--level=7` starts the run on that level of Depths.levels().
var start_level := 0
## `--perks=twin,quick` hands those out at the start.
var start_perks: Array = []
## `--seed=5` a fixed seed.
var fixed_seed := -1
## `--speed=8` runs the game that much faster.
var test_speed := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()
	apply_settings()


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key: String in DEFAULTS:
		settings[key] = cfg.get_value("settings", key, DEFAULTS[key])
	high_scores = cfg.get_value("scores", "high_scores", [])
	runs_played = cfg.get_value("scores", "runs_played", 0)
	wins = cfg.get_value("scores", "wins", 0)
	deepest = cfg.get_value("scores", "deepest", 0)
	daily = cfg.get_value("scores", "daily", {})
	seen_help = cfg.get_value("progress", "seen_help", false)


func save() -> void:
	# A test run leaves the player's save alone.
	if autoplay:
		return
	var cfg := ConfigFile.new()
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.set_value("scores", "high_scores", high_scores)
	cfg.set_value("scores", "runs_played", runs_played)
	cfg.set_value("scores", "wins", wins)
	cfg.set_value("scores", "deepest", deepest)
	cfg.set_value("scores", "daily", daily)
	cfg.set_value("progress", "seen_help", seen_help)
	cfg.save(SAVE_PATH)


func apply_settings() -> void:
	Audio.set_volume(Audio.MUSIC, float(settings.music))
	Audio.set_volume(Audio.SOUNDS, float(settings.sounds))
	if not (OS.has_feature("web") or DisplayServer.get_name() == "headless"):
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	settings_changed.emit()


func toggle_fullscreen() -> void:
	settings.fullscreen = not settings.fullscreen
	apply_settings()
	save()


func new_run(mode := Run.NORMAL, seed_value := -1) -> Run:
	run = Run.new()
	var chosen := seed_value
	if fixed_seed >= 0:
		chosen = fixed_seed
	if chosen < 0:
		chosen = randi()
	run.start(mode, chosen, start_level)
	for perk: String in start_perks:
		run.add_perk(perk)
	runs_played += 1
	return run


## Puts the run in the books. Returns its place in the table (from 0), or -1.
func record_run(the_run: Run, won: bool) -> int:
	if won:
		wins += 1
	deepest = maxi(deepest, the_run.level_index)
	var entry := {
		"score": the_run.score,
		"level": the_run.level_index,
		"depth": the_run.level().depth,
		"time": the_run.time,
		"won": won,
		"hard": the_run.mode == Run.HARD,
		"date": Time.get_date_string_from_system(),
	}
	var place := -1
	for i in high_scores.size():
		if the_run.score > int(high_scores[i].score):
			place = i
			break
	if place < 0 and high_scores.size() < HIGH_SCORES:
		place = high_scores.size()
	if place >= 0:
		high_scores.insert(place, entry)
		high_scores.resize(mini(high_scores.size(), HIGH_SCORES))
	if the_run.mode == Run.DAILY:
		var today := Time.get_date_string_from_system()
		if daily.get("date", "") != today:
			daily = {"date": today, "best": 0, "tries": 0}
		daily.tries = int(daily.tries) + 1
		daily.best = maxi(int(daily.best), the_run.score)
	save()
	return place


## Today's seed: the same for everyone.
func daily_seed() -> int:
	return hash(Time.get_date_string_from_system() + "firedamp") & 0x7fffffff


## "v1.0 abcdef": the version and the commit, for the title. A build has the
## commit in commit.txt; from the project, git knows it.
func version_text() -> String:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var commit := ""
	if FileAccess.file_exists("res://commit.txt"):
		commit = FileAccess.get_file_as_string("res://commit.txt").strip_edges()
	elif OS.has_feature("editor") and not OS.has_feature("web"):
		var out := []
		if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], out) == 0 and not out.is_empty():
			commit = String(out[0]).strip_edges()
	return "v%s %s" % [version, commit]
