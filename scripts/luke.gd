class_name Luke
extends CharacterBody2D
## Luke — the "pet retard" NPC (Luke's own words about himself).
##
## Behavior:
## - Wanders the ground floor: idle, pick a spot, walk to it, repeat.
## - Every so often he drifts to his game setup and starts gaming. That
##   registers the "Remind Luke to get back to work" task. Nag him (E) to
##   complete it; once nagged he stays off the games for the rest of the day.
## - Press E near him any time: he drops one of his unhinged voice lines and
##   Taylor's serotonin AND cortisol both jump +10. Equal parts joy and stress.
##
## Godot conventions:
## - CharacterBody2D + move_and_slide(): the standard kinematic body. We set
##   `velocity` and Godot handles collisions.
## - Dialogue is decoupled: Luke calls GameState.say(), the HUD listens for
##   the luke_said signal and shows the box. Luke never touches UI directly.

const SPEED: float = 110.0
const WANDER_MIN_X: float = -1100.0
const WANDER_MAX_X: float = -120.0  # stays on the flat ground, clear of the pond and tower
const GAME_SETUP_X: float = -1050.0
const INTERACT_RADIUS: float = 72.0

# Luke's voice lines — verbatim, as dictated. Do not "fix" the spelling.
const LINES: Array[String] = [
	"oh my god taylor craziest thing today i ran into an old freind and he let me try his DMT it was pretty nuts",
	"yo taylor some chick wants to know if you would be down for a threesome idk seems kinda off but i figured id ask",
	"dude you would not belive what happened some dude in my discord got banned for CP",
	"yo taylor i just signed us up for a marathon in quebec this december it seems like it might be fun",
]
# Nag responses are new lines (not from the dictated list) — marked as such.
const NAG_RESPONSES: Array[String] = [
	"fine, FINE — i'm getting up. happy?",
	"ok ok. one more match and then work. i mean— yes, work now.",
	"you're right. you're right. putting the headset down.",
]

enum State { IDLE, WALK, GAMING, DELEGATED }

var _state: int = State.IDLE
var _idle_timer: float = 1.0
var _target_x: float = 0.0
var _going_to_game: bool = false
var _game_timer: float = 0.0
var _game_cooldown: float = 20.0  # seconds before he may start gaming again
var _nagged_today: bool = false
var _player_near: bool = false

# --- DELEGATION mode state --------------------------------------------------
# When Taylor presses Q at a chore station (DELEGATION mode only), Luke walks
# to the station and works it at HALF SPEED (2x work_seconds) — delegating is
# never free. station.gd calls assign_delegation(); ModeDelegation owns the
# break-chance/fix-task logic.
var _delegated_task_id: String = ""
var _delegated_station_title: String = ""
var _delegated_work_left: float = 0.0
var _delegated_arrived: bool = false


func _is_delegation_mode() -> bool:
	# Every mode file implements mode_id() -> ModeManager.Mode.X.
	var m := GameState.mode_node()
	return m != null and m.has_method("mode_id") and m.mode_id() == ModeManager.Mode.DELEGATION


func _is_meltdown_mode() -> bool:
	var m := GameState.mode_node()
	return m != null and m.has_method("mode_id") and m.mode_id() == ModeManager.Mode.MELTDOWN

var _sprite: AnimatedSprite2D
var _prompt: Label


func _ready() -> void:
	# Stations find Luke through this group when Taylor delegates a chore
	# (DELEGATION mode).
	add_to_group("luke")
	# Sprite: the Gojo walk sheet (8 frames of 32x32). Built in code from
	# AtlasTextures so we don't need a SpriteFrames resource file.
	var tex: Texture2D = load("res://Player/GojoWalk-Sheet.png")
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", _atlas_frame(tex, 0))
	frames.set_animation_speed(&"idle", 1.0)
	frames.set_animation_loop(&"idle", true)
	frames.add_animation(&"walk")
	for i in 8:
		frames.add_frame(&"walk", _atlas_frame(tex, i))
	frames.set_animation_speed(&"walk", 8.0)
	frames.set_animation_loop(&"walk", true)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.play(&"idle")
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)

	var area := Area2D.new()
	var area_shape := CollisionShape2D.new()
	var area_circle := CircleShape2D.new()
	area_circle.radius = INTERACT_RADIUS
	area_shape.shape = area_circle
	area.add_child(area_shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	_prompt = Label.new()
	_prompt.text = "E — talk"
	_prompt.position = Vector2(-40, -64)
	_prompt.size = Vector2(80, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(1, 1, 0.6)
	_prompt.hide()
	add_child(_prompt)

	GameState.task_list_changed.connect(_on_tasks_changed)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	match _state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0 * delta)
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_pick_action()
		State.WALK:
			var dir: float = signf(_target_x - global_position.x)
			velocity.x = dir * SPEED
			_sprite.flip_h = dir < 0.0
			if absf(_target_x - global_position.x) < 8.0:
				_arrive()
		State.GAMING:
			velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0 * delta)
			# He games indefinitely until nagged — see _physics note in _pick_action.
		State.DELEGATED:
			# DELEGATION mode: he walked to the station (via WALK); now he
			# stands there doing the chore at half speed. Nagging won't help.
			velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0 * delta)
			if _delegated_arrived:
				_delegated_work_left -= delta
				if _delegated_work_left <= 0.0:
					_finish_delegation()

	move_and_slide()
	_sprite.play(&"walk" if absf(velocity.x) > 10.0 else &"idle")


func _process(delta: float) -> void:
	_game_cooldown -= delta


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.keycode != KEY_E or not key_event.pressed or key_event.echo:
		return
	if not _player_near:
		return
	_talk()


func _talk() -> void:
	# MELTDOWN mode: when cortisol is over 70 he drops the act and goes mean.
	var m := GameState.mode_node()
	if _is_meltdown_mode() and GameState.cortisol > 70.0 and m.has_method("mean_line"):
		GameState.say("LUKE", String(m.mean_line()))
		GameState.interact_luke_mean()
		return
	# The core Luke interaction: unhinged wisdom, +10 joy AND +10 stress.
	GameState.say("LUKE", LINES[randi_range(0, LINES.size() - 1)])
	GameState.interact_luke()
	if _state == State.GAMING and _remind_task_active():
		GameState.complete_task(String(GameState.REMIND_LUKE_TASK["id"]))
		GameState.say("LUKE", NAG_RESPONSES[randi_range(0, NAG_RESPONSES.size() - 1)])
		_stop_gaming()


func _pick_action() -> void:
	# He only starts gaming if he hasn't been nagged today and the cooldown
	# has elapsed — otherwise he just wanders.
	if not _nagged_today and _game_cooldown <= 0.0 and randf() < 0.45:
		_going_to_game = true
		_target_x = GAME_SETUP_X
		_state = State.WALK
	else:
		_going_to_game = false
		_target_x = randf_range(WANDER_MIN_X, WANDER_MAX_X)
		_state = State.WALK


func _arrive() -> void:
	velocity.x = 0.0
	if _going_to_game:
		_going_to_game = false
		_start_gaming()
	elif _is_delegation_mode() and _delegated_task_id != "":
		# Reached the chore station — start the (slow) work phase.
		_state = State.DELEGATED
		_delegated_arrived = true
		GameState.say("LUKE", "ok ok i'm here. this better not take long.")
	else:
		_state = State.IDLE
		_idle_timer = randf_range(1.0, 3.5)


func _start_gaming() -> void:
	_state = State.GAMING
	_game_timer = 25.0
	GameState.register_task(
		String(GameState.REMIND_LUKE_TASK["id"]),
		String(GameState.REMIND_LUKE_TASK["label"]),
		float(GameState.REMIND_LUKE_TASK["relief"]))
	var world := get_parent()
	if world.has_method("spawn_float_text"):
		world.spawn_float_text(global_position + Vector2(0, -80),
			"Luke is gaming...", Color(1.0, 0.7, 0.3))


func _stop_gaming() -> void:
	_state = State.IDLE
	_idle_timer = 2.0
	_nagged_today = true
	_game_cooldown = 40.0


func _remind_task_active() -> bool:
	for t in GameState.tasks:
		if t["id"] == String(GameState.REMIND_LUKE_TASK["id"]) and not t["done"]:
			return true
	return false


# --- Delegation API (DELEGATION mode; called by station.gd on Q) ---------------
## Returns {"ok": bool, "reason": String}. Refuses while mid-match — nag him
## off the games first, THEN put him to work. That's the management loop.

func is_available_for_delegation() -> bool:
	# Busy = gaming, or already holding a delegated job (even while walking).
	return _state != State.GAMING and _delegated_task_id == ""


func assign_delegation(task_id: String, station_x: float, station_title: String, work_seconds: float) -> Dictionary:
	if _state == State.GAMING:
		return {"ok": false, "reason": "he's mid-match (nag him first)"}
	if _delegated_task_id != "":
		return {"ok": false, "reason": "he's already working"}
	_delegated_task_id = task_id
	_delegated_station_title = station_title
	# Luke works at half speed: the real cost of delegation.
	_delegated_work_left = work_seconds * 2.0
	_delegated_arrived = false
	_going_to_game = false
	_target_x = station_x
	_state = State.WALK
	GameState.say("LUKE", "ughhh FINE. i'll do the %s. but i'm doing it MY way." % station_title.to_lower())
	return {"ok": true, "reason": ""}


func delegation_status() -> String:
	## Short status line for the HUD's Luke widget (DELEGATION mode).
	if _delegated_task_id != "":
		if _delegated_arrived:
			return "🔧 Luke: working (%s)" % _delegated_station_title
		return "🔧 Luke: walking to %s" % _delegated_station_title
	if _state == State.GAMING:
		return "🎮 Luke: gaming (nag him!)"
	return "💤 Luke: vibing"


func _finish_delegation() -> void:
	var task_id := _delegated_task_id
	var title := _delegated_station_title
	_delegated_task_id = ""
	_delegated_station_title = ""
	_delegated_arrived = false
	_state = State.IDLE
	_idle_timer = randf_range(1.5, 3.5)
	var m := GameState.mode_node()
	if GameState.complete_task(task_id, "luke"):
		var broke := false
		if m != null and m.has_method("maybe_spawn_break"):
			broke = bool(m.maybe_spawn_break(title))
		var world := get_parent()
		if broke:
			GameState.say("LUKE", "ok it's done. ...don't look too close at it.")
			if world.has_method("spawn_float_text"):
				world.spawn_float_text(global_position + Vector2(0, -80),
					"Luke broke something!", Color(1.0, 0.4, 0.3))
		else:
			GameState.say("LUKE", "done. you're welcome. i'm going back to doing nothing.")
			if world.has_method("spawn_float_text"):
				world.spawn_float_text(global_position + Vector2(0, -80),
					"Luke did a chore!", Color(0.6, 1.0, 0.6))


func _on_tasks_changed(tasks: Array) -> void:
	# A new day clears the task list — reset the nag flag so he can game again,
	# and drop any in-progress delegation (its task no longer exists).
	var found := false
	var delegation_alive := false
	for t in tasks:
		if t["id"] == String(GameState.REMIND_LUKE_TASK["id"]):
			found = true
		if t["id"] == _delegated_task_id and not t["done"]:
			delegation_alive = true
	if not found:
		_nagged_today = false
		if _state == State.GAMING:
			_state = State.IDLE
			_idle_timer = 2.0
	if _is_delegation_mode() and _delegated_task_id != "" and not delegation_alive:
		_delegated_task_id = ""
		_delegated_station_title = ""
		_delegated_arrived = false
		if _state == State.DELEGATED or (_state == State.WALK and not _going_to_game):
			_state = State.IDLE
			_idle_timer = 2.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_prompt.hide()


func _atlas_frame(tex: Texture2D, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(index * 32, 0, 32, 32)
	return atlas
