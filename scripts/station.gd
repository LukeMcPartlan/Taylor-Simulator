class_name Station
extends Area2D
## An interactable spot in the house, built entirely in code by world.gd.
##
## Three kinds:
## - CHORE: press E near it to open its WarioWare-style minigame (via the
##   MinigameLauncher autoload). Win the minigame = the linked GameState task
##   completes and cortisol drops. Lose = the task stays open, retry anytime.
## - FUN: press E to play its minigame; winning grants serotonin (cooldown
##   between wins).
## - STORE: the Night Store (DELEGATION mode only; other modes use their own
##   walk-up store nodes spawned by world.gd). Press E to browse upgrades,
##   1/2/3 to buy with serotonin. STORE stations never call the launcher.
##
## DELEGATION mode extras (all gated on _del() != null):
## - Press Q at a chore to DELEGATE it to Luke (he works it slowly at 2x time
##   in his DELEGATED state; see luke.gd). He refuses while mid-match.
## - If Luke broke something ("Fix what Luke broke" task open), hold E at ANY
##   chore station for 2s to fix it.
##
## Godot conventions:
## - Area2D.body_entered / body_exited: Godot calls these when a physics body
##   overlaps the Area2D's shape. We check `body.is_in_group("player")` so we
##   react to Taylor and nothing else.
## - `class_name Station`: registers this script as a global type, so world.gd
##   can write `Station.new()`. (The alternative is `preload("station.gd")`.)
## - InputEventKey in _unhandled_input: the standard way to catch key presses
##   without defining a custom InputMap action in project.godot.

enum Kind { CHORE, FUN, STORE }

# Set by world.gd right after Station.new().
var station_id: String = ""        # GameState task id (chores only)
var title: String = "Station"
var kind: int = Kind.CHORE
var minigame_id: String = ""       # MinigameLauncher id, e.g. "dishes" (CHORE/FUN only)
var work_seconds: float = 3.0      # chores: Luke's delegation pace is 2x this (DELEGATION)
var serotonin_per_use: float = 8.0 # fun: serotonin per minigame win
var fun_cooldown: float = 2.0      # fun: seconds between uses

const INTERACT_RADIUS: float = 64.0
const CHORE_COLOR := Color(0.62, 0.44, 0.26)
const FUN_COLOR := Color(0.55, 0.35, 0.75)
const STORE_COLOR := Color(0.25, 0.45, 0.75)
const DIMMED := Color(0.4, 0.4, 0.4)
const DELEGATED_TINT := Color(1.0, 0.72, 0.35)

## Production furniture art per station (Luke-supplied sprites, native
## resolution). The station spawns on its Spawns/<station_id> marker; the
## sprite sits on the floor there. Stations with no supplied sprite keep
## the old generated placeholder art.
const STATION_SPRITES := {
	"laundry": "res://art/furniture/washer.png",
	"dishes": "res://art/furniture/microwaveInterior.png",
	"book": "res://art/furniture/bookshelf.png",
	"feed_baby": "res://placeholder art/Furniture/high_chair.png",
	"change_baby": "res://placeholder art/Furniture/changing_table.png",
	"basement_toilet": "res://art/furniture/toilet.png",
	"take_out_trash": "res://art/furniture/trash_can.png",
	"microwave": "res://art/furniture/microwave.png",
	"amazon_boxes": "res://art/furniture/amazon_box.png",
}

var _player_inside: bool = false
# Fix-up flow only (DELEGATION): hold-E to repair Luke's mess (2s).
var _fixing: bool = false
var _fix_progress: float = 0.0
var _cooldown_left: float = 0.0

var _visual: CanvasItem  # Sprite2D when placeholder art exists, else the ColorRect
var _title_label: Label
var _prompt: Label
var _bar: ProgressBar

# Night Store shop UI (STORE kind only, DELEGATION mode).
var _shop_open: bool = false
var _shop_layer: CanvasLayer
var _shop_list: VBoxContainer
var _shop_wallet: Label


## The DELEGATION mode node, or null in other modes. All delegation logic
## lives on the mode node; this script just routes input to it.
func _del() -> Node:
	var m := GameState.mode_node()
	if m != null and m.has_method("mode_id") and m.mode_id() == ModeManager.Mode.DELEGATION:
		return m
	return null


func _ready() -> void:
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
		# Placeholder furniture art: bottom of the sprite sits on the floor.
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = Vector2(0, -tex.get_height() / 2.0)
		add_child(spr)
		_visual = spr
		title_y = -(tex.get_height() + 36.0)
		prompt_y = title_y - 34.0
	else:
		# No art for this station (e.g. the STORE): the old colored box.
		var rect := ColorRect.new()
		rect.size = Vector2(72, 52)
		rect.position = Vector2(-36, -52)
		match kind:
			Kind.CHORE:
				rect.color = CHORE_COLOR
			Kind.FUN:
				rect.color = FUN_COLOR
			Kind.STORE:
				rect.color = STORE_COLOR
				rect.size = Vector2(96, 64)
				rect.position = Vector2(-48, -64)
		add_child(rect)
		_visual = rect

	_title_label = _make_label(title, Vector2(-70, title_y), Vector2(140, 24), 18)
	add_child(_title_label)

	# Prompt names the minigame so players learn which game each station runs.
	if kind == Kind.STORE:
		_prompt = _make_label("", Vector2(-110, -140), Vector2(220, 24), 16)
		_build_shop()
	else:
		var game_name := MinigameLauncher.display_name(minigame_id)
		_prompt = _make_label("E: " + game_name, Vector2(-90, prompt_y), Vector2(180, 24), 16)
	_prompt.modulate = Color(1, 1, 0.6)
	_prompt.hide()
	add_child(_prompt)

	# Hold-E repair bar (DELEGATION mode only; hidden otherwise).
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.position = Vector2(-45, -130)
	_bar.size = Vector2(90, 12)
	_bar.hide()
	add_child(_bar)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.task_list_changed.connect(_on_tasks_changed)
	_refresh_from_tasks()


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if _fixing:
		var d := _del()
		var fix_seconds: float = 2.0
		if d != null and d.has_method("fix_work_seconds"):
			fix_seconds = float(d.fix_work_seconds())
		_fix_progress += delta / fix_seconds
		_bar.value = _fix_progress
		if _fix_progress >= 1.0:
			_finish_fix()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		# E released: stop any in-progress repair.
		if key_event.keycode == KEY_E and kind == Kind.CHORE:
			_cancel_fix()
		return

	# Shop is open: number keys buy, E/Escape closes.
	if _shop_open:
		match key_event.keycode:
			KEY_1:
				_buy_upgrade(0)
			KEY_2:
				_buy_upgrade(1)
			KEY_3:
				_buy_upgrade(2)
			KEY_E, KEY_ESCAPE:
				_close_shop()
		return

	if not _player_inside or MinigameLauncher.is_open():
		return

	var d := _del()
	if key_event.keycode == KEY_Q and kind == Kind.CHORE and d != null:
		_try_delegate(d)
		return

	if key_event.keycode != KEY_E:
		return
	if kind == Kind.FUN:
		if _cooldown_left <= 0.0 and minigame_id != "":
			MinigameLauncher.open(minigame_id, _on_minigame_done)
	elif kind == Kind.STORE:
		if d != null and d.has_method("store_open_now") and bool(d.store_open_now()):
			_open_shop()
	elif kind == Kind.CHORE:
		_on_chore_e_pressed(d)


func _on_chore_e_pressed(d: Node) -> void:
	## E at a chore station: Taylor plays the minigame herself (her own open
	## chore only). If her own chore is done/delegated but Luke broke
	## something (DELEGATION), E starts the hold-E repair instead. A chore
	## delegated to Luke is HIS job — no double-dipping.
	## PRACTICE mode: every minigame is open, task or no task.
	if GameState.minigames_always_open():
		if minigame_id != "":
			MinigameLauncher.open(minigame_id, _on_minigame_done)
		return
	if _own_task_open() and not _own_task_delegated():
		if minigame_id != "":
			MinigameLauncher.open(minigame_id, _on_minigame_done)
	elif d != null and d.has_method("fix_task_open") and bool(d.fix_task_open()):
		_start_fix()


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
			_notify("-%d cortisol" % int(relief), Color(0.5, 0.9, 1.0))
		_notify_award()
	# Combo-mom clear-time bonus: beating par extends the combo window and
	# awards Taylor Points. Called AFTER complete_task()/add_serotonin() so
	# the combo window was just refreshed.
	var clear_bonus := GameState.record_minigame_clear(minigame_id, _elapsed_seconds)
	if clear_bonus > 0:
		_notify("+%d PTS clear bonus!" % clear_bonus, Color(1.0, 0.9, 0.3))
	_refresh_from_tasks()


# --- Delegation (Q) ----------------------------------------------------------

func _try_delegate(d: Node) -> void:
	## Q pressed: ask the mode node to hand this chore to Luke, then hand Luke
	## the job. If he refuses (mid-match), the delegation is cancelled again.
	## Luke "plays" the chore off-screen in his DELEGATED state (luke.gd) —
	## his minigame is never rendered, he just works it slowly at 2x time.
	var res: Dictionary = d.try_delegate(station_id)
	if not bool(res.get("ok", false)):
		_notify("Can't delegate: " + String(res.get("reason", "?")), Color(1.0, 0.6, 0.3))
		return
	var luke := get_tree().get_first_node_in_group("luke")
	if luke == null or not luke.has_method("assign_delegation"):
		d.cancel_delegation(station_id)
		_notify("Luke is nowhere to be found?!", Color(1.0, 0.6, 0.3))
		return
	var assigned: Dictionary = luke.assign_delegation(
		station_id, global_position.x, title, work_seconds)
	if not bool(assigned.get("ok", false)):
		d.cancel_delegation(station_id)
		_notify("Luke: " + String(assigned.get("reason", "?")), Color(1.0, 0.6, 0.3))
	else:
		_notify("Delegated! (he's slow…)", Color(1.0, 0.8, 0.4))
	_refresh_from_tasks()


# --- Fix what Luke broke (hold-E repair, DELEGATION) -------------------------

func _start_fix() -> void:
	_fixing = true
	_fix_progress = 0.0
	_bar.value = 0.0
	_bar.show()
	_prompt.hide()


func _cancel_fix() -> void:
	if _fixing:
		_fixing = false
		_fix_progress = 0.0
		_bar.hide()
		_update_prompt()


func _finish_fix() -> void:
	_fixing = false
	_bar.hide()
	var d := _del()
	var fix_id := "fix_luke_mess"
	if d != null and d.has_method("fix_task_id"):
		fix_id = String(d.fix_task_id())
	var relief := _task_relief(fix_id)
	if GameState.complete_task(fix_id):
		_notify("Mess fixed! -%d cortisol" % int(relief), Color(0.6, 1.0, 0.6))
	_refresh_from_tasks()


# --- Night Store (STORE kind, DELEGATION mode) --------------------------------

func _build_shop() -> void:
	# Screen-space overlay: full-rect dim + centered panel with the upgrades.
	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 10
	_shop_layer.hide()
	add_child(_shop_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_layer.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := _make_label("🌙 NIGHT STORE — upgrades are FOREVER",
		Vector2.ZERO, Vector2(460, 30), 22)
	vbox.add_child(header)

	_shop_wallet = _make_label("", Vector2.ZERO, Vector2(460, 24), 18)
	vbox.add_child(_shop_wallet)

	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_shop_list)

	var footer := _make_label("Press 1/2/3 to buy · E to close",
		Vector2.ZERO, Vector2(460, 24), 16)
	footer.modulate = Color(1, 1, 0.6)
	vbox.add_child(footer)


func _open_shop() -> void:
	_refresh_shop()
	_shop_open = true
	_shop_layer.show()


func _close_shop() -> void:
	_shop_open = false
	_shop_layer.hide()
	_update_prompt()


func _refresh_shop() -> void:
	var d := _del()
	if d == null:
		return
	for child in _shop_list.get_children():
		child.queue_free()
	_shop_wallet.text = "Your serotonin: %d" % int(GameState.serotonin)
	var upgrades: Array = d.get_upgrades()
	var idx := 0
	for def in upgrades:
		idx += 1
		var line := _make_label("", Vector2.ZERO, Vector2(460, 52), 17)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var owned: bool = d.has_upgrade(String(def["id"]))
		if owned:
			line.text = "%d. %s %s — SOLD" % [idx, String(def["emoji"]), String(def["name"])]
			line.modulate = Color(0.45, 0.45, 0.45)
		else:
			var afford: bool = GameState.serotonin >= float(def["cost"])
			line.text = "%d. %s %s — %d serotonin\n     %s" % [
				idx, String(def["emoji"]), String(def["name"]),
				int(def["cost"]), String(def["desc"])]
			line.modulate = Color(1, 1, 1) if afford else Color(1.0, 0.5, 0.5)
		_shop_list.add_child(line)


func _buy_upgrade(index: int) -> void:
	var d := _del()
	if d == null:
		return
	var upgrades: Array = d.get_upgrades()
	if index < 0 or index >= upgrades.size():
		return
	var def: Dictionary = upgrades[index]
	var res: Dictionary = d.buy_upgrade(String(def["id"]))
	if bool(res.get("ok", false)):
		_notify("Bought %s %s!" % [String(def["emoji"]), String(def["name"])],
			Color(0.5, 1.0, 0.6))
	else:
		_notify("Nope: " + String(res.get("reason", "?")), Color(1.0, 0.6, 0.3))
	_refresh_shop()
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


func _own_task_delegated() -> bool:
	for t in GameState.tasks:
		if t["id"] == station_id:
			return bool(t.get("delegated", false))
	return false


func _task_relief(task_id: String) -> float:
	for t in GameState.tasks:
		if t["id"] == task_id:
			return float(t["cortisol_relief"])
	return 0.0


func _refresh_from_tasks() -> void:
	if kind == Kind.STORE:
		return
	if kind != Kind.CHORE:
		return
	var d := _del()
	# State language: open = full color, done = dimmed gray, delegated =
	# orange, robot-covered = blue. ColorRects get a base color + modulate;
	# sprites bake their color in, so the state rides on modulate alone.
	var base := CHORE_COLOR
	var mod := Color(1, 1, 1)
	if GameState.minigames_always_open():
		# PRACTICE mode: every minigame is open — stations never dim.
		pass
	elif d != null and d.has_method("is_auto_covered") and bool(d.is_auto_covered(station_id)):
		# A bought upgrade handles this chore: dim it blue, robots at work.
		mod = Color(0.55, 0.7, 1.0)
	elif _own_task_open():
		# Delegated chores glow orange — that's Luke's problem now.
		mod = DELEGATED_TINT if _own_task_delegated() else Color(1, 1, 1)
	else:
		# Done (or not registered today): dim the furniture.
		base = DIMMED
		_fixing = false
		_bar.hide()
	if _visual is ColorRect:
		(_visual as ColorRect).color = base
	elif base == DIMMED:
		mod = Color(0.45, 0.45, 0.45)
	_visual.modulate = mod
	_update_prompt()


func _update_prompt() -> void:
	if not _player_inside:
		_prompt.hide()
		return
	var d := _del()
	if kind == Kind.FUN:
		_prompt.text = "E — " + MinigameLauncher.display_name(minigame_id)
		_prompt.modulate = Color(1, 1, 0.6)
		_prompt.show()
	elif kind == Kind.STORE:
		if d != null and d.has_method("store_open_now") and bool(d.store_open_now()):
			_prompt.text = "E — Night Store (OPEN!)"
			_prompt.modulate = Color(0.5, 1.0, 0.6)
		else:
			_prompt.text = "Night Store — opens 9 PM"
			_prompt.modulate = Color(0.7, 0.7, 0.7)
		_prompt.show()
	elif d != null and d.has_method("is_auto_covered") and bool(d.is_auto_covered(station_id)):
		_prompt.text = "🤖 AUTO — robots have it"
		_prompt.modulate = Color(0.55, 0.75, 1.0)
		_prompt.show()
	elif GameState.minigames_always_open():
		# PRACTICE: no task needed — the minigame is just open.
		_prompt.text = "E — %s" % MinigameLauncher.display_name(minigame_id)
		_prompt.modulate = Color(1, 1, 0.6)
		_prompt.show()
	elif _own_task_open():
		if _own_task_delegated():
			if d != null and d.has_method("fix_task_open") and bool(d.fix_task_open()):
				_prompt.text = "Hold E — fix Luke's mess"
				_prompt.modulate = Color(0.6, 1.0, 0.6)
			else:
				_prompt.text = "🔧 Luke's job…"
				_prompt.modulate = Color(1.0, 0.8, 0.4)
			_prompt.show()
		else:
			_prompt.text = "E — %s · Q — delegate" % MinigameLauncher.display_name(minigame_id)
			_prompt.modulate = Color(1, 1, 0.6)
			_prompt.show()
	elif d != null and d.has_method("fix_task_open") and bool(d.fix_task_open()):
		_prompt.text = "Hold E — fix Luke's mess"
		_prompt.modulate = Color(0.6, 1.0, 0.6)
		_prompt.show()
	else:
		_prompt.hide()


func _notify_award() -> void:
	## Combo-mom: pop the "+N PTS (xM)" award after a scoring clear.
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
