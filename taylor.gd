extends CharacterBody2D
## Taylor — the player. A standard Godot CharacterBody2D platformer controller:
## gravity pulls down, move_and_slide() resolves collisions.
##
## Godot conventions:
## - `velocity` is built into CharacterBody2D; you set it, then call
##   move_and_slide() and the engine moves the body and slides along floors.
## - `is_on_floor()` is only accurate after a move_and_slide() call.
## - Input.is_action_just_pressed("ui_accept"): Godot's default input map has
##   ui_left/ui_right/ui_accept (arrows + Space/Enter). We ALSO read A/D/W
##   directly via InputEventKey so WASD works without touching the InputMap.

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var _jump_queued: bool = false


func _unhandled_input(event: InputEvent) -> void:
	# WASD support: queue a jump on W/Space keypress (ui_accept already covers
	# Space/Enter via the default input map; this just adds W).
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_W:
			_jump_queued = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if (Input.is_action_just_pressed("ui_accept") or _jump_queued) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	_jump_queued = false

	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		direction = -1.0
	elif Input.is_key_pressed(KEY_D):
		direction = 1.0
	if direction:
		# Combo-mom's Comfy Shoes perk can raise move speed via the mode hook.
		velocity.x = direction * SPEED * GameState.get_move_speed_mult()

		if direction < 0:
			sprite_2d.flip_h = true
		elif direction > 0:
			sprite_2d.flip_h = false
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
