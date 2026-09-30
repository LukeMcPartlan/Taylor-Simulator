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
## Seconds of holding jump for a full charge.
const JUMP_CHARGE_TIME = 1.0
const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")


func _charge_max_mult() -> float:
	# Moon Shoes: how high a FULLY charged jump goes (tiered). 1.0 = no
	# shoes, so holding jump does nothing special.
	return _UPGRADE_DEFS.tier_fx("moon_shoes",
		GameState.upgrade_tier("moon_shoes"), "charge_mult", 1.0)


func _charged_jump_velocity(charge: float) -> float:
	## Jump velocity for a release at the given charge (0 = untapped tap =
	## the normal jump, 1 = fully charged).
	return JUMP_VELOCITY * lerpf(1.0, _charge_max_mult(), clampf(charge, 0.0, 1.0))

@onready var sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var _jump_charge: float = 0.0
var _was_jump_held: bool = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not GameState.sim_running:
		# End-of-day overlay (or menu): Taylor is frozen — no movement or
		# jump input until the next day starts.
		_jump_charge = 0.0
		_was_jump_held = false
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	# Jump: HOLD to charge (Moon Shoes), RELEASE to leap. A quick tap is an
	# uncharged jump — exactly the old hop. W/Space/Enter all count as jump.
	var jump_held := Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_W)
	if is_on_floor():
		if jump_held:
			_jump_charge = minf(_jump_charge + delta / JUMP_CHARGE_TIME, 1.0)
		elif _was_jump_held:
			velocity.y = _charged_jump_velocity(_jump_charge)
			_jump_charge = 0.0
	else:
		_jump_charge = 0.0
	_was_jump_held = jump_held

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
