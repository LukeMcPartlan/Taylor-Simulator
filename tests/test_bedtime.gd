extends SceneTree
## Headless test for the bedtime system (2026-09-26):
##  - each chore procs at most 3x/day (reduced from 5)
##  - "Go to bed" chore spawns at 9pm as an invisible station at the bed
##  - E at the bed ends the day normally (serotonin kept, reason "bedtime")
##  - reaching 1 AM without bedding wipes serotonin and ends the day
##    (reason "past_bedtime"); the old 11pm auto-end is gone
##  - the HUD clock wraps past midnight (1:00 AM, not 1:00 PM)
##
## Run: godot --headless --script tests/test_bedtime.gd
##
## NOTE: bare autoload names do not resolve when a script is compiled as the
## --script main loop, so singletons are looked up as untyped vars.

var _failures: Array = []
var _checks: int = 0
var GS = null
var MM = null


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
	_boot()
	_run_tests()
	return false


func _boot() -> void:
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	MM.set_mode(0)  # CLASSIC (Cortisol Mode)
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	GS.add_child(hook)
	GS.set("mode_hook", hook)
	GS.set("day_number", 0)
	GS.start_new_day()
	var scene: PackedScene = load("res://Main.tscn")
	root.add_child(scene.instantiate())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _task_open(id: String) -> bool:
	for t in GS.get("tasks"):
		if String(t["id"]) == id and not bool(t["done"]):
			return true
	return false


func _run_tests() -> void:
	await _frames(10)
	var world = root.get_node("Main/World")

	# --- Proc cap: 3/day per chore -------------------------------------------
	_check(int(GS.get("PROC_MAX_PER_DAY")) == 3, "PROC_MAX_PER_DAY == 3")
	var all_three := true
	for def in GS.get("task_defs"):
		var did := String(def.get("id", ""))
		# amazon_boxes never procs (max_procs 0): it only opens on purchase.
		if did != "amazon_boxes" and int(def.get("max_procs", 0)) != 3:
			all_three = false
	_check(all_three, "every proccing TASK_DEF has max_procs == 3")
	var amazon_def: Dictionary = {}
	for def in GS.get("task_defs"):
		if String(def.get("id", "")) == "amazon_boxes":
			amazon_def = def
	_check(int(amazon_def.get("max_procs", -1)) == 0, "amazon_boxes has max_procs == 0 (never procs)")

	# --- 9pm: "Go to bed" clock task fires ------------------------------------
	GS.set("time_hours", 21.0)
	GS.set("cortisol", 10.0)
	GS.set("dopamine", 80.0)
	await _frames(5)
	_check(_task_open("go_to_bed"), "go_to_bed task opens at 9pm")

	# --- Bed station: invisible node at the bed marker ------------------------
	var bed_station = null
	for n in world.get_children():
		var sid = n.get("station_id")
		if sid != null and String(sid) == "go_to_bed":
			bed_station = n
	_check(bed_station != null, "go_to_bed station spawned")
	if bed_station != null:
		var spawns = world.get_node_or_null("Spawns")
		var marker = spawns.get_node_or_null("go_to_bed") if spawns != null else null
		_check(marker is Node2D, "Spawns/go_to_bed marker exists on the map")
		if marker is Node2D:
			var d: float = (bed_station as Node2D).global_position.distance_to(
				(marker as Node2D).global_position)
			_check(d < 1.0, "go_to_bed station sits on its bed marker")
		# No sprite: transparent visual only (text prompt), per the spec.
		var vis = bed_station.get("_visual")
		var transparent := vis is ColorRect and (vis as ColorRect).color.a < 0.01
		_check(transparent, "go_to_bed station has no visible sprite")

	# --- E at the bed ends the day, serotonin kept ----------------------------
	GS.set("serotonin", 55.0)
	var day_before: int = int(GS.get("day_number"))
	GS.call("go_to_bed")
	await _frames(3)
	_check(not bool(GS.get("sim_running")), "go_to_bed() ends the day")
	_check(String(GS.get_day_summary().get("end_reason", "")) == "bedtime",
		"bedtime end_reason recorded")
	_check(float(GS.get("serotonin")) > 0.0, "serotonin kept when going to bed on time")
	_check(int(GS.get("day_number")) == day_before, "day counter unchanged by bedtime")

	# --- 11pm no longer auto-ends the day --------------------------------------
	GS.start_new_day()
	await _frames(3)
	GS.set("time_hours", 23.5)
	GS.set("cortisol", 10.0)
	GS.set("dopamine", 80.0)
	GS.set("serotonin", 55.0)
	await _frames(5)
	_check(bool(GS.get("sim_running")), "day still running at 11:30pm (no 11pm auto-end)")

	# --- 1 AM without bedding: serotonin wiped, day ends -----------------------
	GS.set("serotonin", 55.0)
	GS.set("time_hours", 25.0)
	await _frames(5)
	_check(not bool(GS.get("sim_running")), "day ends at 1 AM")
	_check(float(GS.get("serotonin")) == 0.0, "serotonin wiped at 1 AM")
	_check(String(GS.get_day_summary().get("end_reason", "")) == "past_bedtime",
		"past_bedtime end_reason recorded")

	# --- Clock wraps past midnight ---------------------------------------------
	GS.set("time_hours", 25.0)
	_check(String(GS.call("_format_time")) == "1:00 AM", "25.0 formats as 1:00 AM")
	GS.set("time_hours", 24.0)
	_check(String(GS.call("_format_time")) == "12:00 AM", "24.0 formats as 12:00 AM")
	GS.set("time_hours", 23.5)
	_check(String(GS.call("_format_time")) == "11:30 PM", "23.5 still formats as 11:30 PM")

	# --- Nursery moved: crib + feed_baby one tile left, dresser half a tile ----
	var crib = world.get_node_or_null("Decor/crib")
	_check(crib is Node2D and absf((crib as Node2D).position.x - 381.0) < 0.01,
		"crib moved one tile left (x=381)")
	var feed_marker = world.get_node_or_null("Spawns/feed_baby")
	_check(feed_marker is Node2D and absf((feed_marker as Node2D).position.x - 387.0) < 0.01,
		"feed_baby marker moved one tile left (x=387)")
	var dresser = world.get_node_or_null("Decor/dresser")
	_check(dresser is Node2D and absf((dresser as Node2D).position.x - 480.0) < 0.01,
		"dresser moved half a tile left (x=480)")

	# --- Bed prompt before 9pm names the opening time --------------------------
	GS.start_new_day()
	await _frames(3)
	GS.set("time_hours", 20.0)
	await _frames(3)
	_check(not _task_open("go_to_bed"), "go_to_bed task not open at 8pm")
	if bed_station != null:
		bed_station.set("_player_inside", true)
		bed_station.call("_update_prompt")
		var prompt_text: String = (bed_station.get("_prompt") as Label).text
		_check("9:00 PM" in prompt_text,
			"bed prompt shows opening time at 8pm (%s)" % prompt_text)
		bed_station.set("_player_inside", false)
		bed_station.call("_update_prompt")

	# --- Day end teleports Taylor to bed ---------------------------------------
	var taylor = get_nodes_in_group("player")[0]
	(taylor as Node2D).global_position = Vector2(-1500, -100)
	GS.call("_end_day")
	await _frames(3)
	var bed_pos: Vector2 = world.call("bed_position")
	_check(((taylor as Node2D).global_position - bed_pos).length() < 2.0,
		"day end teleports taylor to bed")

	print("BEDTIME TEST: %d checks, %d failures" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
