class_name Chris
extends CharacterBody2D
## Chris — the kid NPC. Placeholder art: Luke's sprite tinted all black.
##
## Daily loop:
## - Starts the day ASLEEP in bed (west end of the ground floor).
## - 7am "Wake up Chris" clock task: Taylor wakes him (E) and he leaves for
##   the day (school).
## - 2:30pm (14.5): he comes home through the east edge, then wanders the
##   ground floor dropping garbage every few seconds.
## - Garbage (scripts/garbage.gd): walk over it to pick it up, -2 cortisol
##   each. Chris stops dropping when MAX_GARBAGE pieces are on the floor.
##
## If Taylor never wakes him, he sleeps through the whole day (no garbage).

const SPEED: float = 95.0
# Chris's sleep/spawn spot: the Spawns/chris marker in Main.tscn (draggable
# in the editor). He also walks back in at this Y when he comes home.
const CHRIS_BED_FALLBACK := Vector2(-1700.0, -110.0)
var _bed_pos: Vector2 = CHRIS_BED_FALLBACK
const HOME_EDGE_X: float = -120.0   # east edge: where he walks in at 2:30pm
const HOME_HOUR: float = 14.5       # 2:30 PM
const WANDER_MIN_X: float = -1600.0
const WANDER_MAX_X: float = -150.0
const INTERACT_RADIUS: float = 72.0
const DROP_MIN_SECS: float = 4.0
const DROP_MAX_SECS: float = 7.0
const MAX_GARBAGE: int = 12
const GARBAGE_SCRIPT := preload("res://scripts/garbage.gd")

const LINES: Array[String] = [
	"did you see my other shoe? it's the cool one",
	"school was boring. can i have a snack",
	"i'm NOT the one who drew on the wall. probably",
]

enum State { SLEEPING, AWAY, WANDER }

var _state: int = State.SLEEPING
var _woke_today: bool = false
var _idle_timer: float = 1.0
var _target_x: float = 0.0
var _drop_timer: float = 5.0
var _player_near: bool = false

var _sprite: AnimatedSprite2D
var _prompt: Label


func _ready() -> void:
	add_to_group("chris")
	# Same walk sheet as Luke, tinted all black (placeholder art).
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
	_sprite.modulate = Color(0.0, 0.0, 0.0)
	_sprite.scale = Vector2(2, 2)
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
	_prompt.position = Vector2(-40, -64)
	_prompt.size = Vector2(80, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(1, 1, 0.6)
	_prompt.hide()
	add_child(_prompt)

	GameState.day_started.connect(_on_day_started)
	# Spawn/sleep spot comes from the scene marker so it stays in sync with
	# the editor on every mode.
	var marker := get_parent().get_node_or_null("Spawns/chris")
	if marker is Node2D:
		_bed_pos = (marker as Node2D).global_position
	_go_to_sleep(true)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	match _state:
		State.SLEEPING, State.AWAY:
			velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0 * delta)
		State.WANDER:
			if _idle_timer > 0.0:
				velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0 * delta)
				_idle_timer -= delta
				if _idle_timer <= 0.0:
					_target_x = randf_range(WANDER_MIN_X, WANDER_MAX_X)
			else:
				var dir: float = signf(_target_x - global_position.x)
				velocity.x = dir * SPEED
				_sprite.flip_h = dir < 0.0
				if absf(_target_x - global_position.x) < 8.0:
					velocity.x = 0.0
					_idle_timer = randf_range(1.0, 3.0)

	move_and_slide()
	_sprite.play(&"walk" if absf(velocity.x) > 10.0 else &"idle")


func _process(delta: float) -> void:
	# 2:30pm: walks in the east edge, but only if Taylor woke him up.
	if _state == State.AWAY and _woke_today \
			and GameState.sim_running and GameState.time_hours >= HOME_HOUR:
		_come_home()
		return
	if _state == State.WANDER and GameState.sim_running:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			_drop_timer = randf_range(DROP_MIN_SECS, DROP_MAX_SECS)
			_drop_garbage()
	if _player_near:
		_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.keycode != KEY_E or not key_event.pressed or key_event.echo:
		return
	if not _player_near or _state != State.SLEEPING:
		# Wandering Chris just chats.
		if _player_near and _state == State.WANDER:
			GameState.say("CHRIS", LINES[randi_range(0, LINES.size() - 1)])
		return
	if _task_open("wake_chris"):
		_wake_up()


func _task_open(task_id: String) -> bool:
	for t in GameState.tasks:
		if String(t["id"]) == task_id and not bool(t["done"]):
			return true
	return false


func _wake_up() -> void:
	GameState.complete_task("wake_chris")
	_woke_today = true
	GameState.say("CHRIS", "five more minut— wait, SCHOOL?! ughhh.")
	# Off to school: gone until 2:30pm. (If Taylor somehow wakes him after
	# 2:30, he just starts wandering.)
	if GameState.time_hours >= HOME_HOUR:
		_state = State.WANDER
		_sprite.rotation = 0.0
		_idle_timer = 1.0
	else:
		_state = State.AWAY
		visible = false
	_refresh_prompt()


func _come_home() -> void:
	visible = true
	global_position = Vector2(HOME_EDGE_X, _bed_pos.y)
	_state = State.WANDER
	_sprite.rotation = 0.0
	_idle_timer = 0.5
	_drop_timer = randf_range(2.0, 4.0)
	GameState.say("CHRIS", "i'm HOME! ...what's for snack?")
	var world := get_parent()
	if world.has_method("spawn_float_text"):
		world.spawn_float_text(global_position + Vector2(0, -80),
			"Chris is home", Color(1.0, 0.85, 0.4))


func _drop_garbage() -> void:
	var world := get_parent()
	var existing: int = 0
	for node in world.get_children():
		if node.is_in_group("garbage"):
			existing += 1
	if existing >= MAX_GARBAGE:
		return
	var g: Area2D = GARBAGE_SCRIPT.new()
	g.position = global_position + Vector2(randf_range(-14.0, 14.0), 34.0)
	world.add_child(g)


func _go_to_sleep(teleport: bool) -> void:
	_state = State.SLEEPING
	_woke_today = false
	velocity = Vector2.ZERO
	visible = true
	if teleport:
		global_position = _bed_pos
	_sprite.rotation = PI / 2.0
	_sprite.play(&"idle")
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _state == State.SLEEPING:
		_prompt.text = "E — wake up" if _task_open("wake_chris") else "💤"
	elif _state == State.WANDER:
		_prompt.text = "E — talk"
	else:
		_prompt.text = ""


func _on_day_started(_day: int) -> void:
	# New day: back in bed, asleep, waiting on the 7am wake-up.
	for node in get_parent().get_children():
		if node.is_in_group("garbage"):
			node.queue_free()
	_go_to_sleep(true)


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
