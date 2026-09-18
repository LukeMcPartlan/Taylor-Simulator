extends Control
## Main menu: pick one of the 5 Taylor Simulator game modes.
##
## Built in code (like the rest of the project's UI): title, five selectable
## mode cards with best-stat lines read from each mode's save file, keyboard
## (up/down + Enter) and mouse support, and a "How to play" toggle.
##
## Selecting a mode sets ModeManager.current_mode and loads the game scene.
## Note: GameState is an autoload, so it persists across the scene change —
## its _ready() already ran at startup (in CLASSIC mode), so after the player
## picks a mode we tell it to rebuild with the new mode before switching.

const GAME_SCENE := "res://Main.tscn"
## Press Start 2P (OFL licensed, in assets/fonts/): the chunky pixel look.
## It renders ~1.6x larger than the default font, so all sizes below are
## scaled down to compensate.
const PIXEL_FONT: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _cards: Array = []          # the 5 card PanelContainers, in MODE_CARDS order
var _selected: int = 0
var _how_layer: CanvasLayer
var _how_visible: bool = false


func _ready() -> void:
	_build()
	_select(0)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background: dark cozy purple.
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "TAYLOR SIMULATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "16 hours. 2 meters. 1 unhinged husband. good luck."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", PIXEL_FONT)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 8)
	vbox.add_child(spacer)

	# Mode cards.
	for card_def in ModeManager.MODE_CARDS:
		var card := _make_card(card_def)
		vbox.add_child(card)
		_cards.append(card)

	var footer := Label.new()
	footer.text = "↑↓ / click to choose · Enter to start · H for how to play"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", PIXEL_FONT)
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(footer)

	_how_layer = _make_how_panel()
	_how_layer.hide()
	add_child(_how_layer)


func _make_card(card_def: Dictionary) -> PanelContainer:
	var mode: int = int(card_def["mode"])
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.13, 0.24)
	style.border_color = Color(0.35, 0.3, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = String(card_def["name"])
	name_label.add_theme_font_override("font", PIXEL_FONT)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	vbox.add_child(name_label)

	var desc := Label.new()
	desc.text = String(card_def["desc"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", PIXEL_FONT)
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.85, 0.82, 0.92))
	vbox.add_child(desc)

	var best := Label.new()
	best.text = _best_stat_line(mode)
	best.add_theme_font_override("font", PIXEL_FONT)
	best.add_theme_font_size_override("font_size", 10)
	best.add_theme_color_override("font_color", Color(0.55, 0.9, 0.6))
	vbox.add_child(best)

	# Mouse: hover selects, click starts. gui_input is the Control-level
	# callback for mouse events on this panel.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_card_gui_input.bind(mode))
	panel.mouse_entered.connect(_on_card_hover.bind(mode))
	return panel


func _best_stat_line(mode: int) -> String:
	## Reads each mode's own save file for a best-stat line. Modes never
	## share save files, so one mode's progress can't clobber another's.
	match mode:
		ModeManager.Mode.NIGHT_SHIFT:
			var cfg := ConfigFile.new()
			if cfg.load("user://nightshift_save.cfg") == OK:
				var days := int(cfg.get_value("meta", "best_days", 0))
				var score := int(cfg.get_value("meta", "best_score", 0))
				if days > 0 or score > 0:
					return "Best run: %d days · %d pts" % [days, score]
			return "No runs yet — the laptop awaits"
		ModeManager.Mode.MELTDOWN:
			return "3 lives. No mercy. No save scumming."
		ModeManager.Mode.DELEGATION:
			var cfg := ConfigFile.new()
			if cfg.load("user://delegation_save.cfg") == OK:
				var owned: Array = Array(cfg.get_value("upgrades", "owned", []))
				if not owned.is_empty():
					return "Upgrades owned: %d/3" % owned.size()
			return "No upgrades yet — Luke is still useless"
		ModeManager.Mode.COMBO_MOM:
			var cfg := ConfigFile.new()
			if cfg.load("user://combo_save.cfg") == OK:
				var best := int(cfg.get_value("scores", "best_score", 0))
				if best > 0:
					return "Best score: %s" % _fmt_points(best)
			return "No high score yet — go be a mommy"
	return "The original Taylor experience"


func _fmt_points(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _make_how_panel() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var lines := [
		"HOW TO PLAY",
		"",
		"You are Taylor. The day runs 6:00 AM → 11:00 PM.",
		"",
		"• SEROTONIN (green): your happiness. Fun restores it —",
		"  read the book, doomscroll TikTok on the phone.",
		"• CORTISOL (red): your stress. Chores relieve it — laundry,",
		"  dishes, baby, the basement toilet from hell…",
		"• Open tasks you ignore push cortisol UP. Hit 100 and the day ends.",
		"",
		"Walk to a station, press E to play its minigame.",
		"Talk to Luke (E) for +10 joy AND +10 stress. Worth it.",
		"",
		"Press H or Esc to close this.",
	]
	for line in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_override("font", PIXEL_FONT)
		label.add_theme_font_size_override("font_size", 16 if line == "HOW TO PLAY" else 11)
		vbox.add_child(label)
	return layer


func _on_card_hover(mode: int) -> void:
	# Hovering a card selects it (keyboard and mouse share _selected).
	for i in _cards.size():
		if int(ModeManager.MODE_CARDS[i]["mode"]) == mode:
			_select(i)
			break


func _on_card_gui_input(event: InputEvent, mode: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_start_mode(mode)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		match k:
			KEY_UP, KEY_W:
				_select((_selected - 1 + _cards.size()) % _cards.size())
			KEY_DOWN, KEY_S:
				_select((_selected + 1) % _cards.size())
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _how_visible:
					_toggle_how()
				else:
					_start_mode(int(ModeManager.MODE_CARDS[_selected]["mode"]))
			KEY_H:
				_toggle_how()
			KEY_ESCAPE:
				if _how_visible:
					_toggle_how()


func _select(i: int) -> void:
	_selected = i
	for j in _cards.size():
		var panel: PanelContainer = _cards[j]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		if j == i:
			style.border_color = Color(1.0, 0.8, 0.3)
			style.bg_color = Color(0.22, 0.17, 0.32)
		else:
			style.border_color = Color(0.35, 0.3, 0.5)
			style.bg_color = Color(0.16, 0.13, 0.24)
		panel.add_theme_stylebox_override("panel", style)


func _toggle_how() -> void:
	_how_visible = not _how_visible
	_how_layer.visible = _how_visible


func _start_mode(mode: int) -> void:
	ModeManager.set_mode(mode)
	# GameState (autoload) already ran _ready() at startup in CLASSIC mode.
	# Rebuild its mode node for the chosen mode, then reset the sim so day 1
	# starts clean under the new rules.
	# queue_free() is deferred — the old node would linger until frame end and
	# still receive the day_started signal below. remove_child() + free() is
	# synchronous, so the old mode is truly gone before the new one starts.
	if GameState.mode_hook != null:
		GameState.remove_child(GameState.mode_hook)
		GameState.mode_hook.free()
		GameState.mode_hook = null
	GameState.mode_hook = ModeManager.create_mode()
	if GameState.mode_hook != null:
		GameState.add_child(GameState.mode_hook)
	# Fresh mode = fresh run: reset the day counter before day 1 starts.
	GameState.day_number = 0
	GameState.start_new_day()
	get_tree().change_scene_to_file(GAME_SCENE)
