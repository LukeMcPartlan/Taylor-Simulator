extends SceneTree
## Batch changes (2026-09-30):
##  - one E press = one action: chore stations > NPC chore actions >
##    casual talk (GameState intent arbitration)
##  - serotonin + cortisol reset to 0 at day start
##  - movement/interact locked while the sim isn't running (end-of-day)
##  - chores can't proc within 1 game-hour of being finished
##  - mode unlocks $500; in-run upgrade costs halved; permanent = 4x in-run
##  - base serotonin cap 200 in every mode
##  - DayNight inspector preview (time slider + phase colors)

const MODE_CLASSIC := 0
# Luke's State enum (scripts/luke.gd): IDLE=0, WALK=1, GAMING=2, SLEEPING=3.
const LUKE_IDLE := 0
const LUKE_SLEEPING := 3

var GS
var MM
var _world
var _fails: Array = []
var _checks := 0


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_fails.append(name)
		print("FAIL: ", name)


func _initialize() -> void:
	_boot.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _set_mode(mode: int) -> void:
	MM.set_mode(mode)
	var old_hook = GS.get("mode_hook")
	if old_hook != null and old_hook.has_method("on_mode_enter"):
		old_hook.call("on_mode_enter")


func _e_key() -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = KEY_E
	k.pressed = true
	k.echo = false
	return k


func _open_task(id: String) -> void:
	(GS.get("tasks") as Array).append({"id": id, "done": false})


func _find_station(station_id: String):
	for n in get_nodes_in_group("stations"):
		if String(n.get("station_id")) == station_id:
			return n
	return null


func _boot() -> void:
	var root := get_root()
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	_world = main.get_node("World")
	_set_mode(MODE_CLASSIC)
	GS.call("start_new_day")
	await _frames(5)
	_test_arbitration_core()
	_test_station_priority()
	_test_luke_priority()
	_test_end_of_day_lock()
	_test_meters_reset()
	await _test_proc_cooldown()
	await _test_proc_cooldown_reopen()
	_test_prices()
	_test_cap()
	_test_daynight_preview()
	# Restore: no stray intents left for the next suite.
	GS.set("_interact_intents", [])
	print("RESULT batch_changes: %d checks, %d failures" % [_checks, _fails.size()])
	quit(1 if not _fails.is_empty() else 0)


# --- Interact arbitration ---------------------------------------------------

func _test_arbitration_core() -> void:
	GS.set("_interact_intents", [])
	var ran: Array = []
	GS.call("queue_interact", GS.INTERACT_CASUAL,
		func() -> void: ran.append("casual"))
	GS.call("queue_interact", GS.INTERACT_NPC_CHORE,
		func() -> void: ran.append("npc"))
	GS.call("queue_interact", GS.INTERACT_CHORE,
		func() -> void: ran.append("chore"))
	GS.call("_flush_interact_intents")
	_check(ran == ["chore"], "only the highest-priority intent runs")
	_check((GS.get("_interact_intents") as Array).is_empty(),
		"intents cleared after flush")
	# Tie at the same priority: first registered wins.
	GS.set("_interact_intents", [])
	var ran2: Array = []
	GS.call("queue_interact", GS.INTERACT_CASUAL,
		func() -> void: ran2.append("first"))
	GS.call("queue_interact", GS.INTERACT_CASUAL,
		func() -> void: ran2.append("second"))
	GS.call("_flush_interact_intents")
	_check(ran2 == ["first"], "same-priority tie goes to first registered")


func _test_station_priority() -> void:
	var st = _find_station("dishes")
	_check(st != null, "dishes station exists in the scene")
	st.set("_player_inside", true)
	# No open task: E registers nothing — it must not swallow Luke's wake.
	for t in GS.get("tasks"):
		if String(t["id"]) == "dishes":
			t["done"] = true
	GS.set("_interact_intents", [])
	st._unhandled_input(_e_key())
	_check((GS.get("_interact_intents") as Array).is_empty(),
		"chore station with no open task claims nothing")
	# Open task: E claims the press at CHORE priority.
	_open_task("dishes")
	GS.set("_interact_intents", [])
	st._unhandled_input(_e_key())
	var intents: Array = GS.get("_interact_intents")
	_check(intents.size() == 1
		and int(intents[0]["priority"]) == GS.INTERACT_CHORE,
		"chore station with open task claims CHORE priority")
	# Fun stations claim at casual priority.
	var fun = _find_station("book")
	fun.set("_player_inside", true)
	GS.set("_interact_intents", [])
	fun._unhandled_input(_e_key())
	var fintents: Array = GS.get("_interact_intents")
	_check(fintents.size() == 1
		and int(fintents[0]["priority"]) == GS.INTERACT_CASUAL,
		"fun station claims CASUAL priority")
	GS.set("_interact_intents", [])


func _test_luke_priority() -> void:
	var luke = get_nodes_in_group("luke")[0]
	luke.set("_player_near", true)
	luke.set("_state", LUKE_SLEEPING)
	# Sleeping + wake_luke open: NPC-chore priority.
	_open_task("wake_luke")
	GS.set("_interact_intents", [])
	luke._unhandled_input(_e_key())
	var intents: Array = GS.get("_interact_intents")
	_check(intents.size() == 1
		and int(intents[0]["priority"]) == GS.INTERACT_NPC_CHORE,
		"waking Luke claims NPC_CHORE priority")
	# Station outranks the wake: queue both, only the chore runs.
	var ran: Array = []
	GS.set("_interact_intents", [])
	luke._unhandled_input(_e_key())
	GS.call("queue_interact", GS.INTERACT_CHORE,
		func() -> void: ran.append("chore"))
	GS.call("_flush_interact_intents")
	_check(ran == ["chore"], "chore station beats Luke's wake on one E press")
	# Plain talk (awake, no chore): casual priority.
	for t in GS.get("tasks"):
		if String(t["id"]) == "wake_luke":
			t["done"] = true
	luke.set("_state", LUKE_IDLE)
	GS.set("_interact_intents", [])
	luke._unhandled_input(_e_key())
	var tintents: Array = GS.get("_interact_intents")
	_check(tintents.size() == 1
		and int(tintents[0]["priority"]) == GS.INTERACT_CASUAL,
		"looping Luke talk claims CASUAL priority")
	GS.set("_interact_intents", [])


func _test_end_of_day_lock() -> void:
	# While the sim isn't running (end-of-day overlay), E does nothing.
	GS.set("sim_running", false)
	var st = _find_station("dishes")
	st.set("_player_inside", true)
	_open_task("dishes")
	GS.set("_interact_intents", [])
	st._unhandled_input(_e_key())
	_check((GS.get("_interact_intents") as Array).is_empty(),
		"station E locked while sim not running")
	var luke = get_nodes_in_group("luke")[0]
	luke.set("_player_near", true)
	luke.set("_state", LUKE_IDLE)
	luke._unhandled_input(_e_key())
	_check((GS.get("_interact_intents") as Array).is_empty(),
		"luke E locked while sim not running")
	GS.set("sim_running", true)
	GS.set("_interact_intents", [])


# --- Meters -----------------------------------------------------------------

func _test_meters_reset() -> void:
	GS.set("serotonin", 80.0)
	GS.set("cortisol", 40.0)
	GS.call("start_new_day")
	_check(absf(float(GS.get("serotonin"))) < 0.01,
		"serotonin resets to 0 at day start")
	_check(absf(float(GS.get("cortisol"))) < 0.01,
		"cortisol resets to 0 at day start")


# --- Proc cooldown ----------------------------------------------------------

func _test_proc_cooldown() -> void:
	_set_mode(MODE_CLASSIC)
	GS.call("start_new_day")
	await _frames(3)
	var def: Dictionary = {}
	for d in GS.get("task_defs"):
		if String(d["id"]) == "dishes":
			def = d
	GS.call("_activate_task", def)
	GS.call("complete_task", "dishes")
	# Force 30 proc ticks: dishes must NOT reopen within the hour.
	var reopened := false
	for i in 30:
		GS.set("_next_proc_in_s", 0.0)
		await _frames(1)
		for t in GS.get("tasks"):
			if String(t["id"]) == "dishes" and not bool(t["done"]):
				reopened = true
	_check(not reopened, "finished chore can't proc within 1 game-hour")


func _test_proc_cooldown_reopen() -> void:
	# Past the hour it becomes eligible again.
	GS.set("time_hours", float(GS.get("time_hours")) + 1.5)
	var reopened := false
	for i in 40:
		GS.set("_next_proc_in_s", 0.0)
		await _frames(1)
		for t in GS.get("tasks"):
			if String(t["id"]) == "dishes" and not bool(t["done"]):
				reopened = true
	_check(reopened, "chore can proc again after 1 game-hour")


# --- Prices -----------------------------------------------------------------

func _test_prices() -> void:
	_check(absf(float(load("res://scripts/modes/store_practice.gd").CLASSIC_PRICE) - 500.0) < 0.01,
		"classic unlock costs $500")
	_check(absf(float(load("res://scripts/modes/store_cortisol.gd").DOPAMINE_PRICE) - 500.0) < 0.01,
		"dopamine unlock costs $500")
	_check(absf(float(load("res://scripts/modes/store_cortisol.gd").OXYTOCIN_PRICE) - 500.0) < 0.01,
		"oxytocin unlock costs $500")
	# In-run costs halved; permanent = 4x the in-run price, every tier.
	var defs: Array = UpgradeDefs.DEFS
	var all_ok := true
	for d in defs:
		for tier in d["tiers"]:
			var rc := float(tier["run_cost"])
			var pc := float(tier["perm_cost"])
			if absf(pc - 4.0 * rc) > 0.01:
				all_ok = false
	_check(all_ok, "every permanent tier costs 4x its in-run price")
	var roomba: Dictionary = defs[0]
	_check(absf(float(roomba["tiers"][0]["run_cost"]) - 30.0) < 0.01
		and absf(float(roomba["tiers"][0]["perm_cost"]) - 120.0) < 0.01,
		"roomba T1: $30 in-run / $120 permanent")
	# Permanent purchase actually charges the new price.
	var saved_savings: float = float(GS.get("savings"))
	var saved_perm: Dictionary = (GS.get("permanent_upgrades") as Dictionary).duplicate()
	GS.set("savings", 1000.0)
	GS.set("permanent_upgrades", {})
	var res: Dictionary = GS.call("buy_permanent_upgrade", "sponge")
	_check(bool(res.get("ok", false)), "permanent sponge T1 buyable")
	_check(absf(float(GS.get("savings")) - 940.0) < 0.01,
		"permanent sponge T1 charged $60")
	GS.set("permanent_upgrades", saved_perm)
	GS.set("savings", saved_savings)
	GS.call("save_bank")


# --- Cap --------------------------------------------------------------------

func _test_cap() -> void:
	GS.set("birds_found", [])
	GS.set("permanent_upgrades", {})
	_check(absf(float(GS.call("get_serotonin_cap")) - 200.0) < 0.01,
		"base serotonin cap is 200")


# --- Day/night preview ------------------------------------------------------

func _test_daynight_preview() -> void:
	var dn = _world.get_node("DayNight")
	dn.preview_predawn = Color(0.1, 0.2, 0.3, 0.4)
	var frames: Array = dn.call("_preview_frames")
	_check((frames[0][1] as Color).is_equal_approx(Color(0.1, 0.2, 0.3, 0.4)),
		"inspector preview color feeds the blend")
	var c: Color = DayNight._blend(frames, 6.0)
	_check(c.is_equal_approx(Color(0.1, 0.2, 0.3, 0.4)),
		"preview blend uses the inspector color at 6am")
	# The shipped static curve is untouched.
	var shipped: Color = DayNight.tint_for_hour(6.0)
	_check(shipped.is_equal_approx(Color(0.30, 0.08, 0.45, 0.50)),
		"shipped 6am tint unchanged")
