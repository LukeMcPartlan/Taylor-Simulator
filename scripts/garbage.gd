class_name Garbage
extends Area2D
## Crumpled litter Chris drops while wandering after 2:30pm. Walk over it to
## pick it up: -2 cortisol each. Chris caps how many can be on the floor.

const CORTISOL_RELIEF: float = 2.0

var _t: float = 0.0
var _spr: Sprite2D


func _ready() -> void:
	add_to_group("garbage")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	var spr := Sprite2D.new()
	spr.texture = load("res://placeholder art/Sprites/garbage_ball.png")
	add_child(spr)
	_spr = spr
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	# Crumpled paper ball, slightly wobbling.
	_spr.position.y = sin(_t * 3.0) * 1.5


func vacuum() -> void:
	## Sucked up by the Roomba: no cortisol relief, the robot keeps the joy.
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameState.add_cortisol(-CORTISOL_RELIEF)
	var world := get_parent()
	if world != null and world.has_method("spawn_float_text"):
		world.spawn_float_text(global_position + Vector2(0, -40),
			"-2 cortisol", Color(0.6, 1.0, 0.6))
	queue_free()
