extends SceneTree
## Headless test for NPC locomotion (2026-09-26):
##  - Luke + Chris have the smaller 12px hitbox (was 14)
##  - both patrol back-and-forth: wander targets the FARTHER first-floor end
##  - stuck -> jump: no horizontal progress while trying to walk => hop
##  - Chris AWAY (at school): hitbox + interact area disabled, not a wall
##  - "Put Luke to bed" teleports him to bed (was: walk, got stuck on stairs)
##
## Run: godot --headless --script tests/test_npc_pathing.gd

var _failures: Array = []
var _checks: int = 0
var GS = null


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_failures.append(name)
		print("FAIL: ", name)


func _initialize() -> void:
	pass


var _booted := false


func _process(_delta: float) -> bool:
	if _booted:
		return false
	_booted = true
	_run_tests.call_deferred()
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _body_shape(npc: Node) -> CollisionShape2D:
	# The physics hitbox: CollisionShape2D child that is NOT inside the Area2D.
	for c in npc.get_children():
		if c is CollisionShape2D:
			return c
	return null


func _run_tests() -> void:
	GS = root.get_node("/root/GameState")
	var MM = root.get_node("/root/ModeManager")
	MM.set_mode(0)
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	if hook != null:
		GS.add_child(hook)
		GS.set("mode_hook", hook)
	GS.set("day_number", 0)
	GS.start_new_day()
	root.add_child(load("res://Main.tscn").instantiate())
	await _frames(10)
	var world = root.get_node("Main/World")
	var luke = get_nodes_in_group("luke")[0]
	var chris = get_nodes_in_group("chris")[0]

	# --- smaller hitboxes ------------------------------------------------------
	var luke_shape := _body_shape(luke)
	_check(luke_shape != null and (luke_shape.shape as CircleShape2D).radius == 12.0,
		"npc: luke hitbox radius 12")
	var chris_shape := _body_shape(chris)
	_check(chris_shape != null and (chris_shape.shape as CircleShape2D).radius == 12.0,
		"npc: chris hitbox radius 12")

	# --- back-and-forth patrol: target the farther end --------------------------
	luke.global_position = Vector2(133, -110)
	luke.call("_patrol_next")
	_check(float(luke.get("_target_x")) == 570.0,
		"npc: luke at west end patrols to east end")
	luke.global_position = Vector2(500, -110)
	luke.call("_patrol_next")
	_check(float(luke.get("_target_x")) == 133.0,
		"npc: luke near east end patrols back west")
	chris.global_position = Vector2(133, 32)
	_check(float(chris.call("_patrol_far_end")) == 570.0,
		"npc: chris at west end patrols to east end")
	chris.global_position = Vector2(500, 32)
	_check(float(chris.call("_patrol_far_end")) == 133.0,
		"npc: chris near east end patrols back west")

	# --- stuck -> jump ------------------------------------------------------------
	# Luke asleep at his (upstairs) bed marker: let him land, then fake
	# "no progress". (Poll: headless physics ticks slower than frames.)
	luke.call("_go_to_sleep", true)
	var landed := false
	for i in 150:
		await process_frame
		if luke.is_on_floor():
			landed = true
			break
	_check(landed, "npc: luke on floor before stuck test")
	luke.set("_jump_cooldown", 0.0)
	luke.set("_stuck_timer", 0.7)
	luke.set("_stuck_check_x", luke.global_position.x)
	luke.call("_tick_stuck_jump", 0.71)
	_check(luke.velocity.y < -100.0,
		"npc: luke hops when stuck (vy=%.0f)" % luke.velocity.y)

	# --- wake up heads east first -----------------------------------------------
	# Fresh out of bed Luke patrols east (right) first, not toward the
	# farther end. Synchronous: _wake_up arms it, _pick_action fires it.
	luke.call("_go_to_sleep", true)
	luke.call("_wake_up")
	_check(bool(luke.get("_wake_first")), "npc: wake-up arms east-first patrol")
	luke.call("_pick_action")
	_check(int(luke.get("_state")) == 1, "npc: luke WALK after wake-up pick")
	_check(absf(float(luke.get("_target_x")) - 570.0) < 0.01,
		"npc: luke heads east first (target=%s)" % str(luke.get("_target_x")))
	_check(not bool(luke.get("_wake_first")), "npc: east-first flag clears after one patrol")

	# --- chris AWAY: not a wall ------------------------------------------------------
	GS.call("register_task", "wake_chris", "Wake up Chris", 12.0)
	chris.call("_wake_up")  # before 2:30pm -> AWAY (school)
	await _frames(3)
	_check(int(chris.get("_state")) == 1, "npc: chris AWAY after wake-up")  # Chris.State.AWAY = 1
	_check((chris.get("_body_shape") as CollisionShape2D).disabled,
		"npc: chris hitbox disabled while away")
	_check(not (chris.get("_area") as Area2D).monitoring,
		"npc: chris interact area off while away")
	chris.call("_come_home")
	await _frames(3)
	_check(not (chris.get("_body_shape") as CollisionShape2D).disabled,
		"npc: chris hitbox back on at home")
	_check((chris.get("_area") as Area2D).monitoring,
		"npc: chris interact area back on at home")

	# --- put-luke-to-bed teleports ----------------------------------------------------
	GS.call("register_task", "bed_luke", "Put Luke to bed", 12.0)
	luke.set("_state", 0)  # IDLE, awake
	luke.global_position = Vector2(-1500, -110)  # far from bed
	luke.call("_talk")  # E with bed_luke open -> teleport
	_check(int(luke.get("_state")) == 3, "npc: luke SLEEPING after put-to-bed")
	var bed_pos: Vector2 = luke.get("_bed_pos")
	_check(luke.global_position.distance_to(bed_pos) < 1.0,
		"npc: luke teleported to bed (%s)" % str(luke.global_position))

	print("----")
	print("NPC PATHING TEST: %d checks, %d failures" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
