class_name OptionsMenu
extends CanvasLayer
## In-game pause/options menu. ESC toggles it while roaming the world —
## never inside a minigame (there ESC keeps its instant-quit job, and the
## launcher reports is_open() so we stay out of the way).
##
## Contents: volume slider (persisted to the bank file for future SFX),
## Resume, and Return to Main Menu. The tree pauses while open.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _open := false
var _slider: HSlider
var _vol_label: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide_menu()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	box.add_child(vol_row)

	var vol_name := Label.new()
	vol_name.text = "Volume"
	vol_name.add_theme_font_size_override("font_size", 20)
	vol_row.add_child(vol_name)

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 100.0
	_slider.step = 1.0
	_slider.custom_minimum_size = Vector2(260, 0)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_row.add_child(_slider)

	_vol_label = Label.new()
	_vol_label.add_theme_font_size_override("font_size", 20)
	_vol_label.custom_minimum_size = Vector2(64, 0)
	vol_row.add_child(_vol_label)
	_slider.value_changed.connect(_on_volume_changed)

	var resume := Button.new()
	resume.text = "Resume"
	resume.add_theme_font_size_override("font_size", 22)
	resume.pressed.connect(close_menu)
	box.add_child(resume)

	var quit := Button.new()
	quit.text = "Return to Main Menu"
	quit.add_theme_font_size_override("font_size", 22)
	quit.pressed.connect(_on_quit_to_menu)
	box.add_child(quit)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			# Minigames own ESC (instant quit) — don't fight them.
			if MinigameLauncher.is_open():
				return
			get_viewport().set_input_as_handled()
			if _open:
				close_menu()
			else:
				open_menu()


func open_menu() -> void:
	_open = true
	_slider.set_value_no_signal(_gs().volume * 100.0)
	_update_vol_label()
	visible = true
	get_tree().paused = true


func close_menu() -> void:
	_open = false
	visible = false
	get_tree().paused = false


func hide_menu() -> void:
	_open = false
	visible = false


func _on_volume_changed(v: float) -> void:
	_gs().set_volume(v / 100.0)
	_gs().save_bank()
	_update_vol_label()


func _update_vol_label() -> void:
	_vol_label.text = "%d%%" % int(_gs().volume * 100.0)


func _on_quit_to_menu() -> void:
	# Same teardown as the HUD's day-over "M" shortcut: stop the sim so the
	# menu rebuilds everything fresh on return.
	get_tree().paused = false
	_gs().sim_running = false
	get_tree().change_scene_to_file(MENU_SCENE)


## Autoload lookup (works even where the GameState identifier isn't in scope).
func _gs() -> Node:
	return get_node("/root/GameState")
