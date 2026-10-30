class_name PauseMenu
extends Control
## Esc: the mine waits.

var _resume: Button
var _options_panel: Control
var _column: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.016, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 2)
	UI.center_in(self, _column)
	var title := UI.label("PAUSED", UI.ACCENT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_column.add_child(spacer)
	_resume = UI.button("Carry on")
	_resume.pressed.connect(close)
	_column.add_child(_resume)
	var options := UI.button("Options")
	options.pressed.connect(_open_options)
	_column.add_child(options)
	var quit := UI.button("Back up the shaft")
	quit.pressed.connect(_give_up)
	_column.add_child(quit)
	UI.link_focus([_resume, options, quit])


func open() -> void:
	get_tree().paused = true
	var hud: Hud = get_parent().get_child(0)
	hud.clear_banner()
	visible = true
	_resume.grab_focus()
	Audio.muffle(0.75)
	Audio.play("tick", -6.0)


func close() -> void:
	if _options_panel:
		_options_panel.queue_free()
		_options_panel = null
		_column.visible = true
	visible = false
	get_tree().paused = false
	Audio.muffle(0.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _options_panel:
			_close_options()
		else:
			close()


func _open_options() -> void:
	_column.visible = false
	_options_panel = OptionsPanel.new()
	_options_panel.closed.connect(_close_options)
	add_child(_options_panel)


func _close_options() -> void:
	if _options_panel:
		_options_panel.queue_free()
		_options_panel = null
	_column.visible = true
	_resume.grab_focus()


func _give_up() -> void:
	Game.record_run(Game.run, false)
	get_tree().paused = false
	Audio.muffle(0.0)
	Game.main.show_screen("title", {}, 0.4)
