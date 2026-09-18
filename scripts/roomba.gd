class_name Roomba
extends Node2D
## Amazon purchase: a little guy who patrols the ground floor back and forth
## and vacuums Chris's garbage on touch. No cortisol relief — he's a robot,
## he doesn't get the little dopamine hit. Drawn in code, no sprite needed.

const MIN_X: float = -1500.0
const MAX_X: float = 1500.0
const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")

var _dir: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	position = Vector2(-1400.0, -110.0)


func _process(delta: float) -> void:
	_t += delta
	# Tiered stats: re-read each frame so a mid-run purchase takes effect.
	var tier := GameState.upgrade_tier("roomba")
	var speed := _UPGRADE_DEFS.tier_fx("roomba", tier, "speed", 110.0)
	var radius := _UPGRADE_DEFS.tier_fx("roomba", tier, "radius", 42.0)
	position.x += _dir * speed * delta
	if position.x >= MAX_X:
		_dir = -1.0
	elif position.x <= MIN_X:
		_dir = 1.0
	# Vacuum any garbage we roll over.
	for g in get_tree().get_nodes_in_group("garbage"):
		var node := g as Node2D
		if node != null and node.global_position.distance_to(global_position) < radius:
			if node.has_method("vacuum"):
				node.vacuum()
			else:
				node.queue_free()
	queue_redraw()


func _draw() -> void:
	# Body: dark disc with a lighter top plate.
	draw_circle(Vector2.ZERO, 22.0, Color(0.16, 0.16, 0.18))
	draw_circle(Vector2.ZERO, 22.0, Color(0.05, 0.05, 0.06), false, 2.0)
	draw_circle(Vector2(0, -4), 12.0, Color(0.28, 0.28, 0.32))
	# Sensor eye: blinks red while working.
	var eye := Color(1.0, 0.25, 0.2) if sin(_t * 6.0) > 0.0 else Color(0.5, 0.1, 0.1)
	draw_circle(Vector2(9.0 * _dir, -4), 4.0, eye)
	# Side brush: little spinning bristle.
	var bristle := Vector2(20.0 * _dir, 10) + Vector2(cos(_t * 14.0), sin(_t * 14.0)) * 8.0
	draw_line(Vector2(18.0 * _dir, 8), bristle, Color(0.7, 0.7, 0.7), 3.0)
