extends CanvasLayer
## HUD: serotonin/cortisol bars, day clock, task list, day-over overlay.
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
@onready var clock_label: Label = $ClockLabel
@onready var task_list: VBoxContainer = $TaskPanel/Margin/VBox/TaskList
@onready var day_over_overlay: Control = $DayOverOverlay
@onready var day_over_label: Label = $DayOverOverlay/Center/Panel/Margin/VBox/DayOverLabel
@onready var stats_label: Label = $DayOverOverlay/Center/Panel/Margin/VBox/StatsLabel
@onready var restart_hint: Label = $DayOverOverlay/Center/Panel/Margin/VBox/RestartHint
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/Margin/VBox/SpeakerLabel
@onready var line_label: Label = $DialogueBox/Margin/VBox/LineLabel

var _dialogue_timer: float = 0.0


func _ready() -> void:
	GameState.meters_changed.connect(_on_meters_changed)
	GameState.clock_changed.connect(_on_clock_changed)
	GameState.task_list_changed.connect(_on_task_list_changed)
	GameState.day_ended.connect(_on_day_ended)
	GameState.luke_said.connect(_on_luke_said)
	# Autoloads finish _ready() before scenes do, so day 1 has already started.
	# Pull the current state instead of waiting for the next signal tick.
	_on_meters_changed(GameState.serotonin, GameState.cortisol)
	_on_clock_changed(GameState.get_time_string())
	_on_task_list_changed(GameState.tasks)
	day_over_overlay.hide()
	dialogue_box.hide()


func _process(delta: float) -> void:
	if _dialogue_timer > 0.0:
		_dialogue_timer -= delta
		if _dialogue_timer <= 0.0:
			dialogue_box.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# R restarts the day from the day-over screen.
		if event.keycode == KEY_R and day_over_overlay.visible:
			day_over_overlay.hide()
			GameState.start_new_day()


func _on_meters_changed(serotonin: float, cortisol: float) -> void:
	serotonin_bar.value = serotonin
	cortisol_bar.value = cortisol


func _on_clock_changed(time_string: String) -> void:
	clock_label.text = "Day %d — %s" % [GameState.day_number, time_string]


func _on_task_list_changed(tasks: Array) -> void:
	# Rebuild the list from scratch — simple and always correct for a handful
	# of tasks. Completed ones are dimmed with a checkmark.
	for child in task_list.get_children():
		child.queue_free()
	for t in tasks:
		var label := Label.new()
		if t["done"]:
			label.text = "✓ " + t["label"]
			label.modulate = Color(0.45, 0.45, 0.45)
		else:
			label.text = "• " + t["label"]
		task_list.add_child(label)


func _on_day_ended() -> void:
	var summary: Dictionary = GameState.get_day_summary()
	day_over_label.text = "Day %d complete" % int(summary["day"])
	stats_label.text = "Tasks: %d/%d\nAvg serotonin: %d\nRating: %s" % [
		int(summary["tasks_done"]),
		int(summary["tasks_total"]),
		int(round(float(summary["avg_serotonin"]))),
		String(summary["rating"]),
	]
	restart_hint.text = "Press R for Day %d" % (int(summary["day"]) + 1)
	day_over_overlay.show()


func _on_luke_said(speaker: String, line: String) -> void:
	speaker_label.text = speaker
	line_label.text = "\"" + line + "\""
	dialogue_box.show()
	_dialogue_timer = 4.0
