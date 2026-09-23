extends SceneTree
## Headless verification for the dopamine update:
##  - dopamine starts at 100, drains over the day, clamps at max
##  - hitting zero ends the day (end_reason "dopamine")
##  - the phone is a HUD button now (no walk-up station, no minigame)
##  - the laptop has a draggable Spawns/laptop marker in Main.tscn
##
## Run: godot --headless --script tests/test_dopamine.gd
##
## NOTE: bare autoload names (GameState, ModeManager) do not resolve when a
## script is compiled as the --script main loop, so we look the singletons up
## as untyped vars and dispatch dynamically.

var _failures: Array = []
var _checks: int = 0
var GS = null         # /root/GameState
var MM = null         # /root/ModeManager
const MODE_CLASSIC: int = 0


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_failures.append(name)
		printerr("FAIL: ", name)


func _boot() -> void:
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	MM.set_mode(MODE_CLASSIC)
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
	var scene: PackedScene = load("res://Main.tscn")
	root.add_child(scene.instantiate())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run_tests() -> void:
	var gs = GS
	await _frames(5)

	# --- Dopamine starts full ------------------------------------------------
	# (tolerance 1.0: a few frames of drain happen before the first check)
	_check(absf(float(gs.get("dopamine")) - 100.0) < 1.0,
		"dopamine starts at 100")

	# --- add_dopamine clamps at the max --------------------------------------
	gs.set("dopamine", 90.0)
	gs.call("add_dopamine", 50.0)
	_check(absf(float(gs.get("dopamine")) - 100.0) < 0.01,
		"add_dopamine clamps at 100")

	# --- Dopamine drains over time -------------------------------------------
	gs.set("dopamine", 50.0)
	await _frames(120)
	_check(float(gs.get("dopamine")) < 50.0, "dopamine drains over time")

	# --- Phone is a HUD button, not a station --------------------------------
	var main = root.get_child(root.get_child_count() - 1)
	var phone_btn = main.get_node_or_null("HUD/PhoneButton")
	_check(phone_btn != null and phone_btn is Button,
		"HUD has a PhoneButton")
	var stations := []
	for n in main.find_children("*", "Station", true, false):
		stations.append(n)
	var phone_stations := stations.filter(func(s): return s.get("station_id") == "phone")
	_check(phone_stations.is_empty(), "no walk-up phone station any more")
	_check(stations.size() == 10, "10 stations remain (was 11)")

	# --- Laptop marker exists --------------------------------------------------
	var world = main.get_node_or_null("World")
	_check(world != null and world.get_node_or_null("Spawns/laptop") != null,
		"Spawns/laptop marker exists in Main.tscn")

	# --- Zero dopamine ends the day -------------------------------------------
	gs.set("dopamine", 0.001)
	await _frames(30)
	_check(not bool(gs.get("sim_running")), "dopamine zero ends the day")
	var summary: Dictionary = gs.call("get_day_summary")
	_check(String(summary.get("end_reason", "")) == "dopamine",
		"day summary flags the dopamine ending")

	print("----")
	print("checks: %d  failures: %d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)


func _initialize() -> void:
	# _initialize runs before the tree is active (autoloads not resolvable
	# yet), so the real boot happens on the first _process frame.
	pass


var _booted := false


func _process(_delta: float) -> bool:
	if _booted:
		return false
	_booted = true
	_boot()
	_run_tests()  # async: fire and forget, quits itself at the end
	return false
