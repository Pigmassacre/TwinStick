extends Node
## The title's Options.


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	var bg := ColorRect.new()
	bg.color = Color(0.0235, 0.0196, 0.0314)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	var panel := OptionsPanel.new()
	panel.closed.connect(func() -> void: Game.main.show_screen("title", {}, 0.25))
	ui.add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Game.main.show_screen("title", {}, 0.25)
