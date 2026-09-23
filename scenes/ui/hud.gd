extends CanvasLayer
## HUD (UNIFIED): serotonin/cortisol/dopamine bars, day clock, task list,
## day-over overlay — plus a mode dock where the active game mode adds its
## own widgets (sanity pips, combo readout, Luke status, buff icons...).
##
## Godot conventions used here:
## - `GameState` is the autoload singleton from scripts/autoload/game_state.gd,
##   so it is available by name in every script without an import.
## - `signal.connect(callable)`: subscribing to a signal. Godot then calls our
##   method whenever the signal is emitted.
## - `@onready var x = $Path/To/Node`: grabs a child node once the scene is
##   loaded; `$` is shorthand for get_node().
## - `_unhandled_input(event)`: called for input no Control consumed — the
##   standard place for global hotkeys.

@onready var serotonin_bar: ProgressBar = $TopLeft/Panel/Margin/VBox/SerotoninBar
@onready var cortisol_bar: ProgressBar = $TopLeft/Panel/Margin/VBox/CortisolBar
@onready var dopamine_bar: ProgressBar = $TopLeft/Panel/Margin/VBox/DopamineBar
@onready var serotonin_label: Label = $TopLeft/Panel/Margin/VBox/SerotoninLabel
@onready var cortisol_label: Label = $TopLeft/Panel/Margin/VBox/CortisolLabel
@onready var dopamine_label: Label = $TopLeft/Panel/Margin/VBox/DopamineLabel
@onready var phone_button: Button = $PhoneButton
@onready var dollars_label: Label = $TopLeft/Panel/Margin/VBox/DollarsLabel
@onready var clock_label: Label = $ClockLabel
@onready var mode_tag: Label = $ModeTag
@onready var mode_dock: VBoxContainer = $ModeDock
@onready var task_list: VBoxContainer = $TaskPanel/Margin/VBox/TaskList
@onready var day_over_overlay: Control = $DayOverOverlay
@onready var day_over_label: Label = $DayOverOverlay/Center/Panel/Margin/VBox/DayOverLabel
@onready var stats_label: Label = $DayOverOverlay/Center/Panel/Margin/VBox/StatsLabel
@onready var restart_hint: Label = $DayOverOverlay/Center/Panel/Margin/VBox/RestartHint
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/Margin/VBox/SpeakerLabel
@onready var line_label: Label = $DialogueBox/Margin/VBox/LineLabel

var _dialogue_timer: float = 0.0
## "day" or "run": which overlay is showing. R continues the right thing.
var _overlay_kind: String = "day"
## Phone tuning: each tap gives this much dopamine, then the button locks
## for the cooldown so it can't be spam-clicked to full.
const PHONE_DOPAMINE_GAIN: float = 12.0
const PHONE_COOLDOWN_S: float = 5.0


func _ready() -> void:
	GameState.meters_changed.connect(_on_meters_changed)
	GameState.dopamine_changed.connect(_on_dopamine_changed)
	GameState.dollars_changed.connect(_on_dollars_changed)
	GameState.clock_changed.connect(_on_clock_changed)
	GameState.task_list_changed.connect(_on_task_list_changed)
	GameState.day_ended.connect(_on_day_ended)
	GameState.run_ended.connect(_on_run_ended)
	GameState.luke_said.connect(_on_luke_said)
	phone_button.pressed.connect(_on_phone_pressed)
	# Autoloads finish _ready() before scenes do, so day 1 has already started.
	# Pull the current state instead of waiting for the next signal tick.
	_on_meters_changed(GameState.serotonin, GameState.cortisol)
	_on_dopamine_changed(GameState.dopamine)
	_on_dollars_changed(GameState.dollars)
	_on_clock_changed(GameState.get_time_string())
	_on_task_list_changed(GameState.tasks)
	day_over_overlay.hide()
	dialogue_box.hide()
	# Mode tag under the clock (empty in CLASSIC) and mode-specific widgets.
	mode_tag.text = GameState.get_hud_tag()
	_build_mode_widgets()


func _build_mode_widgets() -> void:
	## Asks the active mode node to populate the right-side dock. Modes add
	## their own Labels/bars here and update them by connecting to GameState
	## signals themselves — the HUD stays dumb about mode internals.
	var m := GameState.mode_node()
	if m != null and m.has_method("build_hud_widgets"):
		m.build_hud_widgets(mode_dock)


func _process(delta: float) -> void:
	if _dialogue_timer > 0.0:
		_dialogue_timer -= delta
		if _dialogue_timer <= 0.0:
			dialogue_box.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and day_over_overlay.visible:
			day_over_overlay.hide()
			match _overlay_kind:
				"run":
					GameState.new_run()
				"meltdown_day":
					GameState.retry_day()
				_:
					GameState.start_new_day()
		elif event.keycode == KEY_M and day_over_overlay.visible:
			# Back to the main menu. GameState is an autoload, so it survives
			# the scene change — but a fresh mode means fresh state, so stop
			# the sim before leaving (the menu rebuilds everything on return).
			GameState.sim_running = false
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_meters_changed(serotonin: float, cortisol: float) -> void:
	# The bar fills against the current serotonin cap (base 200, raised by
	# collectible upgrades).
	var cap := GameState.get_serotonin_cap()
	serotonin_bar.max_value = cap
	serotonin_bar.value = serotonin
	cortisol_bar.value = cortisol
	serotonin_label.text = "SEROTONIN %d / %d" % [int(serotonin), int(cap)]
	cortisol_label.text = "CORTISOL %d" % int(cortisol)


func _on_dopamine_changed(value: float) -> void:
	dopamine_bar.value = value
	dopamine_label.text = "DOPAMINE %d" % int(value)


func _on_phone_pressed() -> void:
	## The phone's whole job now: a tap gives dopamine, no minigame.
	GameState.add_dopamine(PHONE_DOPAMINE_GAIN)
	phone_button.disabled = true
	await get_tree().create_timer(PHONE_COOLDOWN_S).timeout
	phone_button.disabled = false


func _on_dollars_changed(dollars: float) -> void:
	dollars_label.text = "Dollars: $%d" % int(dollars)


func _on_clock_changed(time_string: String) -> void:
	clock_label.text = "Day %d — %s" % [GameState.day_number, time_string]


func _on_task_list_changed(tasks: Array) -> void:
	# Rebuild the list from scratch — simple and always correct for a handful
	# of tasks. Every task gets a checkbox: empty while open, a big green
	# check when done; delegated ones (DELEGATION mode) get a wrench.
	for child in task_list.get_children():
		child.queue_free()
	for t in tasks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var box := Label.new()
		var name := Label.new()
		name.text = String(t["label"])
		name.add_theme_font_size_override("font_size", 16)
		if bool(t["done"]):
			# Big green check next to a green DONE tag, then the label dimmed.
			box.text = "✓"
			box.add_theme_font_size_override("font_size", 26)
			box.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
			var done_tag := Label.new()
			done_tag.text = "DONE"
			done_tag.add_theme_font_size_override("font_size", 16)
			done_tag.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
			row.add_child(box)
			row.add_child(done_tag)
			name.text = " — " + String(t["label"])
			name.modulate = Color(0.45, 0.45, 0.45)
			row.add_child(name)
		elif bool(t.get("delegated", false)):
			box.text = "🔧"
			box.add_theme_font_size_override("font_size", 18)
			name.modulate = Color(1.0, 0.8, 0.4)
			row.add_child(box)
			row.add_child(name)
		else:
			box.text = "☐"
			box.add_theme_font_size_override("font_size", 18)
			name.modulate = Color(1, 1, 1)
			row.add_child(box)
			row.add_child(name)
		task_list.add_child(row)


func _on_day_ended() -> void:
	var summary: Dictionary = GameState.get_day_summary()
	if String(summary.get("end_reason", "")) == "cortisol":
		day_over_label.text = "Day %d cut short — cortisol maxed out!" % int(summary["day"])
	elif String(summary.get("end_reason", "")) == "dopamine":
		day_over_label.text = "Day %d cut short — dopamine hit zero!" % int(summary["day"])
	else:
		day_over_label.text = "Day %d complete" % int(summary["day"])
	var stats := "Tasks: %d/%d\nAvg serotonin: %d\nRating: %s" % [
		int(summary["tasks_done"]),
		int(summary["tasks_total"]),
		int(round(float(summary["avg_serotonin"]))),
		String(summary["rating"]),
	]
	# Modes can append extra lines (e.g. combo-mom's score).
	if summary.has("extra_lines"):
		stats += "\n" + String(summary["extra_lines"])
	stats_label.text = stats
	restart_hint.text = "Press R for Day %d · M for menu" % (int(summary["day"]) + 1)
	_overlay_kind = "day"
	day_over_overlay.show()


func _on_run_ended(title: String, stats: String, restart_kind: String) -> void:
	## A mode ended the run (or a meltdown ended the day). Same overlay,
	## different text: R restarts per restart_kind, M always goes to menu.
	day_over_label.text = title
	stats_label.text = stats
	if restart_kind == "day":
		restart_hint.text = "Press R to redo the day · M for menu"
		_overlay_kind = "meltdown_day"
	else:
		restart_hint.text = "Press R for a new run · M for menu"
		_overlay_kind = "run"
	day_over_overlay.show()


func _on_luke_said(speaker: String, line: String) -> void:
	speaker_label.text = speaker
	line_label.text = "\"" + line + "\""
	dialogue_box.show()
	_dialogue_timer = 4.0
