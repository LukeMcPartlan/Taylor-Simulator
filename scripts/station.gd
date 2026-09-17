class_name Station
extends Area2D
## An interactable spot in the house, built entirely in code by world.gd.
##
## Two kinds:
## - CHORE: press E near it to open its WarioWare-style minigame (via the
##   MinigameLauncher autoload). Win the minigame = the linked GameState task
##   completes and cortisol drops. Lose = the task stays open, retry anytime.
## - FUN: press E to play its minigame; winning grants serotonin (cooldown
##   between wins).
##
## Variant hooks (see GameState): night-shift overrides
## get_minigame_speed_mult(), meltdown overrides MINIGAME_FAIL_CORTISOL and
## minigame_fail_text().
##
## Godot conventions:
## - Area2D.body_entered / body_exited: Godot calls these when a physics body
##   overlaps the Area2D's shape. We check `body.is_in_group("player")` so we
##   react to Taylor and nothing else.
## - `class_name Station`: registers this script as a global type, so world.gd
##   can write `Station.new()`. (The alternative is `preload("station.gd")`.)
## - InputEventKey in _unhandled_input: the standard way to catch key presses
##   without defining a custom InputMap action in project.godot.

enum Kind { CHORE, FUN }

# Set by world.gd right after Station.new().
var station_id: String = ""        # GameState task id (chores only)
var title: String = "Station"
var kind: int = Kind.CHORE
var minigame_id: String = ""       # MinigameLauncher id, e.g. "dishes"
var serotonin_per_use: float = 8.0 # fun: serotonin per minigame win
var fun_cooldown: float = 2.0      # fun: seconds between uses

const INTERACT_RADIUS: float = 64.0
const CHORE_COLOR := Color(0.62, 0.44, 0.26)
const FUN_COLOR := Color(0.55, 0.35, 0.75)
const DIMMED := Color(0.4, 0.4, 0.4)

var _player_inside: bool = false
var _cooldown_left: float = 0.0

var _marker: ColorRect
var _title_label: Label
var _prompt: Label


func _ready() -> void:
	# Taylor (a CharacterBody2D) lives on physics layer 1 by default, and an
	# Area2D's default mask is 1, so body_entered fires for him with no setup.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	add_child(shape)

	# The "furniture": a colored block sitting on the floor.
	_marker = ColorRect.new()
	_marker.size = Vector2(72, 52)
	_marker.position = Vector2(-36, -52)
	_marker.color = CHORE_COLOR if kind == Kind.CHORE else FUN_COLOR
	add_child(_marker)

	_title_label = _make_label(title, Vector2(-70, -104), Vector2(140, 24), 18)
	add_child(_title_label)

	# Prompt names the minigame so players learn which game each station runs.
	var game_name := MinigameLauncher.display_name(minigame_id)
	_prompt = _make_label("E: " + game_name, Vector2(-90, -140), Vector2(180, 24), 16)
	_prompt.modulate = Color(1, 1, 0.6)
	_prompt.hide()
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.task_list_changed.connect(_on_tasks_changed)
	_refresh_from_tasks()


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.keycode != KEY_E or not key_event.pressed or key_event.echo:
		return
	if not _player_inside or MinigameLauncher.is_open():
		return
	if kind == Kind.FUN:
		if _cooldown_left <= 0.0:
			MinigameLauncher.open(minigame_id, _on_minigame_done)
	elif kind == Kind.CHORE:
		if _task_is_open():
			MinigameLauncher.open(minigame_id, _on_minigame_done)


func _on_minigame_done(success: bool, _elapsed_seconds: float = 0.0) -> void:
	## Callback from the launcher after the minigame closes and the tree
	## unpauses. Win = reward; lose = task stays open for an instant retry.
	## _elapsed_seconds is real time spent in the minigame (variants use it
	## for clear-time bonuses); base game ignores it.
	if not success:
		GameState.apply_minigame_fail()
		_notify(GameState.minigame_fail_text(), Color(1.0, 0.5, 0.45))
		_update_prompt()
		return
	if kind == Kind.FUN:
		GameState.add_serotonin(serotonin_per_use)
		_cooldown_left = fun_cooldown
		_notify("+%d serotonin" % int(serotonin_per_use), Color(0.4, 1.0, 0.5))
	else:
		var relief := _task_relief()
		if GameState.complete_task(station_id):
			_notify("-%d cortisol" % int(relief), Color(0.5, 0.9, 1.0))
	_refresh_from_tasks()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_prompt.hide()


func _on_tasks_changed(_tasks: Array) -> void:
	# Day restarts re-register tasks; refresh dimmed state.
	_refresh_from_tasks()


func _task_is_open() -> bool:
	for t in GameState.tasks:
		if t["id"] == station_id:
			return not t["done"]
	return false


func _task_relief() -> float:
	for t in GameState.tasks:
		if t["id"] == station_id:
			return float(t["cortisol_relief"])
	return 0.0


func _refresh_from_tasks() -> void:
	if kind != Kind.CHORE:
		return
	if _task_is_open():
		_marker.color = CHORE_COLOR
		_marker.modulate = Color(1, 1, 1)
	else:
		# Done (or not registered today): dim the furniture.
		_marker.color = DIMMED
	_update_prompt()


func _update_prompt() -> void:
	if not _player_inside:
		_prompt.hide()
		return
	if kind == Kind.FUN:
		_prompt.show()
	elif _task_is_open():
		_prompt.show()
	else:
		_prompt.hide()


func _notify(text: String, color: Color) -> void:
	# world.gd (our parent) owns the floating-text effect helper.
	var world := get_parent()
	if world.has_method("spawn_float_text"):
		world.spawn_float_text(global_position + Vector2(0, -140), text, color)


func _make_label(text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
