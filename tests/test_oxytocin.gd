extends SceneTree
## Headless verification for Oxytocin Mode (mode 7):
##  - oxytocin starts at 50, drains at dopamine's rate, clamps 0..100
##  - talking to Luke gives +10 oxytocin
##  - Q near Luke sends him to the nearest open chore: teleports him,
##    completes it as his work (delegated), costs 10 oxytocin
##  - chore duty does nothing outside Oxytocin Mode
##  - day ends at oxytocin 0 ("oxytocin_zero") or 100 ("oxytocin_max")
##  - menu card exists (locked $500); dopamine store sells the unlock;
##    oxytocin store sells products only
##  - oxytocin's bird is the pigeon
##
## Run: godot --headless --script tests/test_oxytocin.gd
##
## NOTE: bare autoload names (GameState, ModeManager) do not resolve when a
## script is compiled as the --script main loop, so we look the singletons up
## as untyped vars and dispatch dynamically.

var _failures: Array = []
var _checks: int = 0
var GS = null         # /root/GameState
var MM = null         # /root/ModeManager
const MODE_CLASSIC: int = 0
const MODE_DOPAMINE: int = 6
const MODE_OXYTOCIN: int = 7


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_failures.append(name)
		printerr("FAIL: ", name)


func _set_mode(mode: int) -> void:
	MM.set_mode(mode)
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	if hook != null:
		GS.add_child(hook)
		GS.set("mode_hook", hook)


func _boot() -> void:
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	_set_mode(MODE_OXYTOCIN)
	GS.set("day_number", 0)
	GS.start_new_day()
	var scene: PackedScene = load("res://Main.tscn")
	root.add_child(scene.instantiate())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _activate_chore(task_id: String) -> void:
	for def in GS.get("task_defs"):
		if String(def["id"]) == task_id:
			GS.call("_activate_task", def)
			return


func _task(task_id: String) -> Dictionary:
	for t in GS.get("tasks"):
		if String(t["id"]) == task_id:
			return t
	return {}


func _run_tests() -> void:
	var gs = GS
	await _frames(5)

	# --- Oxytocin starts at 50 -----------------------------------------------
	# (tolerance 1.0: a few frames of drain happen before the first check)
	_check(absf(float(gs.get("oxytocin")) - 50.0) < 1.0,
		"oxytocin starts at 50")

	# --- Drain rate matches dopamine's ----------------------------------------
	_check(absf(float(GS.OXYTOCIN_DRAIN_PER_HOUR) - float(GS.DOPAMINE_DRAIN_PER_HOUR)) < 0.001,
		"oxytocin drains at dopamine's rate")
	gs.set("oxytocin", 50.0)
	await _frames(120)
	_check(float(gs.get("oxytocin")) < 50.0, "oxytocin drains over time")

	# --- Talking to Luke gives +10 oxytocin -----------------------------------
	gs.set("oxytocin", 40.0)
	gs.call("interact_luke")
	_check(absf(float(gs.get("oxytocin")) - 50.0) < 0.01,
		"talking to Luke gives +10 oxytocin")

	# --- Talk reward is gated to Oxytocin Mode ---------------------------------
	_set_mode(MODE_CLASSIC)
	gs.set("oxytocin", 40.0)
	gs.call("interact_luke")
	_check(absf(float(gs.get("oxytocin")) - 40.0) < 0.01,
		"talking to Luke gives no oxytocin outside Oxytocin Mode")
	_set_mode(MODE_OXYTOCIN)

	# --- Clamps ----------------------------------------------------------------
	gs.set("oxytocin", 95.0)
	gs.call("add_oxytocin", 50.0)
	_check(absf(float(gs.get("oxytocin")) - 100.0) < 0.01,
		"add_oxytocin clamps at 100")
	gs.set("oxytocin", 5.0)
	gs.call("add_oxytocin", -50.0)
	_check(absf(float(gs.get("oxytocin")) - 0.0) < 0.01,
		"add_oxytocin clamps at 0")

	# --- Q: Luke does a chore (teleport, delegated, -10 oxytocin) --------------
	gs.set("oxytocin", 50.0)
	_activate_chore("laundry")
	await _frames(2)
	var lukes: Array = get_nodes_in_group("luke")
	_check(not lukes.is_empty(), "Luke exists in the scene")
	var luke = lukes[0]
	luke.set("_player_near", true)
	luke.set("_state", 0)  # IDLE: day starts at 6am with Luke still asleep
	var pos_before: Vector2 = luke.global_position
	var oxy0 := float(gs.get("oxytocin"))
	luke.call("_send_to_chore")
	await _frames(2)
	var laundry: Dictionary = _task("laundry")
	_check(bool(laundry.get("done", false)), "chore duty completes the task")
	_check(bool(laundry.get("delegated", false)), "chore duty marks the task delegated")
	var oxy_after := float(gs.get("oxytocin"))
	_check(oxy_after < oxy0 - 9.0 and oxy_after > oxy0 - 11.0,
		"chore duty costs 10 oxytocin")
	_check(luke.global_position.distance_to(pos_before) > 10.0,
		"Luke teleported to the chore station")

	# --- Oxytocin store: products only, no unlock row --------------------------
	var oxy_store = load("res://scripts/modes/store_oxytocin.gd").new()
	root.add_child(oxy_store)
	var oxy_rows: Array = oxy_store.get_rows()
	var oxy_unlocks := oxy_rows.filter(func(r): return String(r.get("kind", "")) == "unlock")
	_check(oxy_unlocks.is_empty(), "oxytocin store sells no mode unlock")
	_check(oxy_rows.size() == 6, "oxytocin store has the 6-product catalog")
	oxy_store.queue_free()

	# --- Dopamine store sells the oxytocin unlock ------------------------------
	_set_mode(MODE_DOPAMINE)
	var dop_store = load("res://scripts/modes/store_dopamine.gd").new()
	root.add_child(dop_store)
	var dop_rows: Array = dop_store.get_rows()
	var oxy_row: Dictionary = {}
	for r in dop_rows:
		if String(r.get("kind", "")) == "unlock" and String(r.get("id", "")) == "oxytocin":
			oxy_row = r
	_check(not oxy_row.is_empty(), "dopamine store sells the oxytocin unlock")
	_check(String(oxy_row.get("price", "")).find("500") >= 0,
		"oxytocin unlock costs $500")
	gs.set("dollars", 1000.0)
	var res: Dictionary = dop_store.buy_row("unlock", "oxytocin")
	_check(bool(res.get("ok", false)), "buying the oxytocin unlock works")
	_check(gs.call("is_mode_unlocked", MODE_OXYTOCIN), "oxytocin unlocks on the menu")
	dop_store.queue_free()
	# Clean up the persisted unlock so other test runs start locked.
	var ul: Array = gs.get("unlocked_modes")
	ul.erase(MODE_OXYTOCIN)
	gs.call("save_bank")

	# --- Menu card --------------------------------------------------------------
	_set_mode(MODE_OXYTOCIN)
	var card: Dictionary = {}
	for c in MM.MODE_CARDS:
		if int(c["mode"]) == MODE_OXYTOCIN:
			card = c
	_check(not card.is_empty(), "oxytocin has a main-menu card")
	_check(String(card.get("locked_desc", "")).find("500") >= 0,
		"oxytocin card mentions the $500 price")
	_check(MM.call("mode_name") == "Oxytocin",
		"mode_name() is Oxytocin in oxytocin mode")

	# --- Zero oxytocin ends the day ---------------------------------------------
	gs.set("oxytocin", 0.001)
	await _frames(30)
	_check(not bool(gs.get("sim_running")), "oxytocin zero ends the day")
	var summary: Dictionary = gs.call("get_day_summary")
	_check(String(summary.get("end_reason", "")) == "oxytocin_zero",
		"day summary flags the oxytocin_zero ending")

	# --- Max oxytocin ends the day ----------------------------------------------
	gs.call("start_new_day")
	await _frames(5)
	gs.set("oxytocin", 100.0)
	await _frames(30)
	_check(not bool(gs.get("sim_running")), "oxytocin max ends the day")
	summary = gs.call("get_day_summary")
	_check(String(summary.get("end_reason", "")) == "oxytocin_max",
		"day summary flags the oxytocin_max ending")

	# --- Chore duty does nothing outside Oxytocin Mode --------------------------
	_set_mode(MODE_CLASSIC)
	gs.call("start_new_day")
	await _frames(5)
	gs.set("oxytocin", 50.0)
	_activate_chore("dishes")
	await _frames(2)
	lukes = get_nodes_in_group("luke")
	luke = lukes[0]
	luke.set("_player_near", true)
	luke.set("_state", 0)  # IDLE: isolate the mode gate, not the sleep gate
	var oxy_before := float(gs.get("oxytocin"))
	luke.call("_send_to_chore")
	await _frames(2)
	_check(not bool(_task("dishes").get("done", false)),
		"no chore duty outside oxytocin mode")
	_check(absf(float(gs.get("oxytocin")) - oxy_before) < 0.01,
		"no oxytocin spent outside oxytocin mode")

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
