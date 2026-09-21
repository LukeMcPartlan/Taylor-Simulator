class_name Killbox
extends Area2D
## Safety net under the level (Main.tscn -> World/Killbox). Anything in the
## "player" group that falls in is put back on solid ground at the nearest
## spawn marker (World/Spawns), with its velocity zeroed.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var target := nearest_spawn(body.global_position)
	if target == null:
		return
	body.global_position = target.global_position
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO


## Closest spawn marker to a world position (null if World/Spawns is missing).
func nearest_spawn(from_pos: Vector2) -> Node2D:
	var spawns := get_node_or_null("../Spawns")
	var best: Node2D = null
	var best_d := INF
	if spawns != null:
		for child in spawns.get_children():
			if child is Node2D:
				var d := (child as Node2D).global_position.distance_to(from_pos)
				if d < best_d:
					best_d = d
					best = child
	return best
