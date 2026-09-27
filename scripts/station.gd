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
## (Walk-up stores are separate Area2D kiosks spawned by world.gd from
## scripts/modes/store_*.gd — not Stations.)
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
var minigame_id: String = ""       # MinigameLauncher id, e.g. "dishes" (CHORE/FUN only)
var work_seconds: float = 3.0      # chores: baseline seconds Taylor takes in the minigame
var serotonin_per_use: float = 8.0 # fun: serotonin per minigame win
var fun_cooldown: float = 2.0      # fun: seconds between uses

const INTERACT_RADIUS: float = 64.0
const CHORE_COLOR := Color(0.62, 0.44, 0.26)
const FUN_COLOR := Color(0.55, 0.35, 0.75)
const DIMMED := Color(0.4, 0.4, 0.4)

## Production furniture art per station (Luke-supplied sprites, drawn at 2x).
## The station spawns on its Spawns/<station_id> marker; the sprite sits on
## the floor there. Stations with no supplied sprite (feed/change baby) keep
## the old colored box.
const STATION_SPRITES := {
	"laundry": "res://art/furniture/washer.png",
	"dishes": "res://art/furniture/kitchen_sink.png",
	"book": "res://art/furniture/bookshelf.png",
	"basement_toilet": "res://art/furniture/toilet.png",
	"take_out_trash": "res://art/furniture/trash_can.png",
	"microwave": "res://art/furniture/microwave.png",
	"amazon_boxes": "res://art/furniture/amazon_box.png",
	"__laptop__": "res://placeholder art/Sprites/laptop.png",
}
# Stations whose furniture visual stays fully transparent (labels/prompts
# still show; the player just walks up to the text).
const TRANSPARENT_VISUALS: Array[String] = ["feed_baby", "change_baby", "go_to_bed"]
# Per-station furniture art overrides. Default is 2x scale, bottom of the
# sprite on the station floor. amazon_boxes is 1x1, nudged one tile lower.
const STATION_SPRITE_SCALE: Dictionary = {
	"amazon_boxes": 1.0,
}
const STATION_SPRITE_Y_OFF: Dictionary = {
	"amazon_boxes": 32.0,
}

var _player_inside: bool = false
var _cooldown_left: float = 0.0

var _visual: CanvasItem  # Sprite2D when placeholder art exists, else the ColorRect
var _title_label: Label
var _prompt: Label


func _ready() -> void:
	add_to_group("stations")  # Luke's Q-key chore duty scans this group.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	add_child(shape)

	var tex: Texture2D = null
	if STATION_SPRITES.has(station_id):
		tex = load(STATION_SPRITES[station_id])
	var title_y := -104.0
	var prompt_y := -140.0
	if tex != null:
		# Furniture art at 2x scale, bottom of the sprite on the floor
		# (per-station overrides in STATION_SPRITE_SCALE / STATION_SPRITE_Y_OFF).
		var art_scale := float(STATION_SPRITE_SCALE.get(station_id, 2.0))
		var y_off := float(STATION_SPRITE_Y_OFF.get(station_id, 0.0))
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2(art_scale, art_scale)
		spr.position = Vector2(0, -tex.get_height() * art_scale * 0.5 + y_off)
		spr.z_index = -1  # furniture draws behind the player
		add_child(spr)
		_visual = spr
		title_y = -(tex.get_height() * art_scale + 36.0) + y_off
		prompt_y = title_y - 34.0
	else:
		# No art for this station: the old colored box.
		# feed_baby / change_baby stay fully transparent — text only.
		var rect := ColorRect.new()
		rect.size = Vector2(72, 52)
		rect.position = Vector2(-36, -52)
		rect.z_index = -1  # furniture draws behind the player
		if station_id in TRANSPARENT_VISUALS:
			rect.color = Color(0, 0, 0, 0)
		else:
			match kind:
				Kind.CHORE:
					rect.color = CHORE_COLOR
				Kind.FUN:
					rect.color = FUN_COLOR
		add_child(rect)
		_visual = rect

	_title_label = _make_label(title, Vector2(-70, title_y), Vector2(140, 24), 18)
	add_child(_title_label)

	# Prompt names the minigame so players learn which game each station runs.
	if station_id == "go_to_bed":
		_prompt = _make_label("E: Go to bed", Vector2(-90, prompt_y), Vector2(180, 24), 16)
	else:
		var game_name := MinigameLauncher.display_name(minigame_id)
		_prompt = _make_label("E: " + game_name, Vector2(-90, prompt_y), Vector2(180, 24), 16)
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
	if not key_event.pressed or key_event.echo:
		return
	if not _player_inside or MinigameLauncher.is_open():
		return
	if key_event.keycode != KEY_E:
		return
	if kind == Kind.FUN:
		if _cooldown_left <= 0.0 and minigame_id != "":
			MinigameLauncher.open(minigame_id, _on_minigame_done)
	elif kind == Kind.CHORE:
		_on_chore_e_pressed()


func _on_chore_e_pressed() -> void:
	## E at a chore station: Taylor plays the minigame herself (her own open
	## chore only).
	## PRACTICE mode: every minigame is open, task or no task.
	## The bed is not a minigame: E with the "Go to bed" task open ends
	## the day on the spot.
	if station_id == "go_to_bed":
		if _own_task_open():
			GameState.go_to_bed()
		return
	if GameState.minigames_always_open():
		if minigame_id != "":
			MinigameLauncher.open(minigame_id, _on_minigame_done)
		return
	if _own_task_open():
		if minigame_id != "":
			MinigameLauncher.open(minigame_id, _on_minigame_done)


func _on_minigame_done(success: bool, _elapsed_seconds: float = 0.0) -> void:
	## Callback from the launcher after the minigame closes and the tree
	## unpauses. Win = reward; lose = task stays open for an instant retry.
	## _elapsed_seconds is real time spent in the minigame (combo-mom's scorer
	## uses it for clear-time bonuses); other modes ignore it.
	if not success:
		GameState.apply_minigame_fail()
		_notify(GameState.minigame_fail_text(), Color(1.0, 0.5, 0.45))
		_update_prompt()
		return
	# "✓ DONE" over the player: fades in place, never follows them.
	var player := get_tree().get_first_node_in_group("player")
	var world := get_parent()
	if player is Node2D and world != null and world.has_method("spawn_done_text"):
		world.call("spawn_done_text",
			(player as Node2D).global_position + Vector2(0, -110))
	if kind == Kind.FUN:
		GameState.add_serotonin(serotonin_per_use * GameState.get_fun_mult())
		_cooldown_left = fun_cooldown
		_notify("+%d serotonin" % int(serotonin_per_use * GameState.get_fun_mult()),
			Color(0.4, 1.0, 0.5))
		_notify_award()
	elif kind == Kind.CHORE:
		var relief := _task_relief(station_id)
		if GameState.complete_task(station_id):
			_notify("-%d cortisol  +%d serotonin" % [int(relief), int(GameState.TASK_COMPLETION_SEROTONIN)], Color(0.5, 0.9, 1.0))
		# Amazon delivery: a Box Breaker WIN delivers every queued order at
		# once (even if the task was already done, e.g. practice sandbox).
		# A loss returns above — orders stay pending.
		if station_id == "amazon_boxes":
			var delivered: Array = GameState.deliver_pending_orders()
			if not delivered.is_empty():
				_notify("📦 Delivered %d order(s)!" % delivered.size(), Color(1.0, 0.85, 0.4))
		_notify_award()
	# Clear-time bonus hook (a mode may score fast clears). Called AFTER
	# complete_task()/add_serotonin().
	var clear_bonus := GameState.record_minigame_clear(minigame_id, _elapsed_seconds)
	if clear_bonus > 0:
		_notify("+%d PTS clear bonus!" % clear_bonus, Color(1.0, 0.9, 0.3))
	_refresh_from_tasks()


# --- Shared ------------------------------------------------------------------

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


func _own_task_open() -> bool:
	for t in GameState.tasks:
		if t["id"] == station_id:
			return not t["done"]
	return false


## Toilet texture: dirty while the task is active, clean when it's done.
const TOILET_CLEAN := preload("res://art/furniture/toilet.png")
const TOILET_DIRTY := preload("res://art/furniture/toilet_dirty.png")
func _toilet_tex(dirty: bool) -> Texture2D:
	return TOILET_DIRTY if dirty else TOILET_CLEAN


func _task_relief(task_id: String) -> float:
	for t in GameState.tasks:
		if t["id"] == task_id:
			return float(t["cortisol_relief"])
	return 0.0


func _refresh_from_tasks() -> void:
	if kind != Kind.CHORE:
		return
	# Basement toilet: dirty sprite while its task is open, clean when done.
	if station_id == "basement_toilet" and _visual is Sprite2D:
		(_visual as Sprite2D).texture = _toilet_tex(_own_task_open())
	# State language: open = full color, done = dimmed gray. ColorRects get a
	# base color + modulate; sprites bake their color in, so the state rides
	# on modulate alone.
	var base := CHORE_COLOR
	var mod := Color(1, 1, 1)
	if GameState.minigames_always_open():
		# PRACTICE mode: every minigame is open — stations never dim.
		pass
	elif not _own_task_open():
		# Done (or not registered today): dim the furniture.
		base = DIMMED
	if _visual is ColorRect and not (station_id in TRANSPARENT_VISUALS):
		(_visual as ColorRect).color = base
	elif base == DIMMED:
		mod = Color(0.45, 0.45, 0.45)
	_visual.modulate = mod
	_update_prompt()


func _update_prompt() -> void:
	if not _player_inside:
		_prompt.hide()
		return
	if kind == Kind.FUN:
		_prompt.text = "E — " + MinigameLauncher.display_name(minigame_id)
		_prompt.modulate = Color(1, 1, 0.6)
		_prompt.show()
	elif GameState.minigames_always_open():
		# PRACTICE: no task needed — the minigame is just open.
		_prompt.text = "E — %s" % MinigameLauncher.display_name(minigame_id)
		_prompt.modulate = Color(1, 1, 0.6)
		_prompt.show()
	elif _own_task_open():
		_prompt.text = "E — %s" % MinigameLauncher.display_name(minigame_id)
		_prompt.modulate = Color(1, 1, 0.6)
		_prompt.show()
	elif station_id == "go_to_bed":
		# Not bedtime yet: say when the bed opens instead of hiding.
		_prompt.text = "🛏 Bed opens at %s" % GameState.format_hour(GameState.BEDTIME_HOUR)
		_prompt.modulate = Color(0.7, 0.7, 0.7)
		_prompt.show()
	else:
		_prompt.hide()


func _notify_award() -> void:
	## Pop the "+N PTS (xM)" award after a scoring clear (mode hook decides).
	var award: Dictionary = GameState.get_last_award()
	if int(award.get("points", 0)) > 0:
		_notify("+%d PTS (x%d)" % [int(award["points"]), int(award["mult"])],
			Color(1.0, 0.9, 0.3))


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
