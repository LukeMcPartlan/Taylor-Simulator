extends SceneTree
## Headless integration test for the 2026-09-18 mega-spec:
##  - 100 cortisol ends the day with zero serotonin (all modes)
##  - nothing drains serotonin any more (neglect only pushes cortisol up)
##  - day starts at 6am; wake_luke@6 / wake_chris@7 / bed_luke@22 clock tasks
##  - Luke sleeps -> woken at 6am -> put to bed at 10pm
##  - Chris (black Luke sprite): woken 7am, home 2:30pm, drops garbage
##  - Amazon boxes chore + Box Breaker minigame
##  - Meltdown mode intercepts 100 cortisol with its own meltdown
##
## Run: godot --headless --script tests/test_mega_spec.gd -- --mode=classic
##      godot --headless --script tests/test_mega_spec.gd -- --mode=meltdown
##
## NOTE: bare autoload names (GameState, ModeManager) do not resolve when a
## script is compiled as the --script main loop, so we look the singletons up
## as untyped vars and dispatch dynamically.

var _failures: Array = []
var _checks: int = 0
var GS = null         # /root/GameState
var MM = null         # /root/ModeManager
const MODE_CLASSIC: int = 0
const MODE_MELTDOWN: int = 2


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_failures.append(name)
		print("FAIL: ", name)


func _task_open(id: String) -> bool:
	for t in GS.tasks:
		if String(t["id"]) == id and not bool(t["done"]):
			return true
	return false


func _initialize() -> void:
	# _initialize runs before the tree is active (autoloads not resolvable
	# yet), so the real boot happens on the first _process frame.
	pass


var _booted := false
var _mode_name := "classic"


func _process(_delta: float) -> bool:
	if _booted:
		return false
	_booted = true
	_boot()
	_run_tests(_mode_name)  # async: fire and forget, quits itself at the end
	return false


func _boot() -> void:
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	var mode_name := "classic"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode_name = a.get_slice("=", 1)
	var mode: int = MODE_MELTDOWN if mode_name == "meltdown" else MODE_CLASSIC
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
	GS.set("day_number", 0)
	GS.start_new_day()
	var scene: PackedScene = load("res://Main.tscn")
	root.add_child(scene.instantiate())
	_mode_name = mode_name


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run_tests(mode_name: String) -> void:
	var gs = GS
	await _frames(5)

	# --- Day starts at 6am --------------------------------------------------
	_check(absf(gs.time_hours - 6.0) < 0.2, "day starts at 6am (got %.2f)" % gs.time_hours)
	_check(_task_open("wake_luke"), "wake_luke clock task procs at 6am")

	# --- Luke asleep in bed -------------------------------------------------
	var luke = get_nodes_in_group("luke")[0]
	_check(luke.get("_state") == 4, "luke starts SLEEPING")  # State.SLEEPING = 4
	_check(luke.global_position.distance_to(Vector2(-1050, -110)) < 8.0,
		"luke starts in bed")

	# --- Chris asleep in bed, black sprite ----------------------------------
	var chris = get_nodes_in_group("chris")[0]
	_check(chris.get("_state") == 0, "chris starts SLEEPING")  # Chris.State.SLEEPING = 0
	_check(chris.visible, "chris visible in bed")
	_check(not _task_open("wake_chris"), "wake_chris not open before 7am")

	# --- Amazon boxes wired -------------------------------------------------
	var found_station := false
	var world = root.get_node("Main/World")
	for n in world.get_children():
		var sid = n.get("station_id")
		if sid == null:
			continue
		if String(sid) == "amazon_boxes":
			found_station = true
			_check(String(n.get("minigame_id")) == "amazon_break",
				"amazon station game = amazon_break")
	_check(found_station, "amazon_boxes station exists")
	var has_def := false
	for d in gs.TASK_DEFS:
		if String(d["id"]) == "amazon_boxes":
			has_def = true
	_check(has_def, "amazon_boxes in TASK_DEFS")

	# --- Nothing drains serotonin; neglect only pushes cortisol up ----------
	var s0: float = gs.serotonin
	var c0: float = gs.cortisol
	gs.register_task("test_neglect", "Test neglect", 5.0)
	await _frames(120)  # ~2 real seconds of open-task pressure
	_check(absf(gs.serotonin - s0) < 0.01,
		"serotonin untouched by neglect (%.1f -> %.1f)" % [s0, gs.serotonin])
	_check(gs.cortisol > c0, "cortisol rises under neglect (%.1f -> %.1f)" % [c0, gs.cortisol])

	# --- Chris: 7am wake -> away -> 2:30pm home -> garbage -------------------
	gs.time_hours = 7.0
	await _frames(3)
	_check(_task_open("wake_chris"), "wake_chris clock task procs at 7am")
	chris.call("_wake_up")
	_check(chris.get("_state") == 1, "chris AWAY after wake")  # State.AWAY = 1
	_check(not chris.visible, "chris hidden while away")
	gs.time_hours = 14.5
	await _frames(5)
	_check(chris.get("_state") == 2, "chris WANDER after 2:30pm")  # State.WANDER = 2
	_check(chris.visible, "chris visible when home")
	chris.call("_drop_garbage")
	await _frames(3)
	var garbage: Array = get_nodes_in_group("garbage")
	_check(garbage.size() >= 1, "chris drops garbage")
	if garbage.size() >= 1:
		var g = garbage[0]
		var player = get_nodes_in_group("player")[0]
		var c_before: float = gs.cortisol
		player.global_position = g.global_position
		await _frames(10)
		_check(get_nodes_in_group("garbage").size() < garbage.size(),
			"walking over garbage picks it up")
		_check(gs.cortisol < c_before, "garbage pickup relieves cortisol")

	# --- Luke: wake at 6am, bed at 10pm --------------------------------------
	luke.call("_talk")  # E while sleeping, wake_luke open
	_check(luke.get("_state") == 0, "luke wakes on E (IDLE)")  # Luke.State.IDLE = 0
	_check(not _task_open("wake_luke"), "wake_luke completes")
	gs.time_hours = 22.0
	await _frames(3)
	_check(_task_open("bed_luke"), "bed_luke clock task procs at 10pm")
	luke.call("_talk")  # E while awake, bed_luke open -> walks to bed
	_check(luke.get("_state") == 1, "luke walks to bed")  # Luke.State.WALK = 1
	luke.global_position = Vector2(-1000, -140)
	await _frames(120)
	_check(luke.get("_state") == 4, "luke SLEEPING after reaching bed")
	_check(not _task_open("bed_luke"), "bed_luke completes")

	# --- Box Breaker minigame ------------------------------------------------
	# (added to the tree: _finish uses a SceneTreeTimer before emitting)
	var game = load("res://scripts/minigames/amazon_break.gd").new()
	game.size = Vector2(700, 560)
	root.add_child(game)
	var result := {}
	game.finished.connect(func(success: bool) -> void: result["ok"] = success)
	game.start()
	game.test_break_all()
	await create_timer(1.6).timeout  # real-time wait: _finish's 1.2s banner beat
	_check(bool(result.get("ok", false)), "box breaker: clearing boxes wins")
	game.queue_free()
	var game2 = load("res://scripts/minigames/amazon_break.gd").new()
	game2.size = Vector2(700, 560)
	root.add_child(game2)
	var result2 := {}
	game2.finished.connect(func(success: bool) -> void: result2["ok"] = success)
	game2.start()
	game2.test_miss_ball()
	game2.test_miss_ball()
	game2.test_miss_ball()
	await create_timer(1.6).timeout
	_check(result2.has("ok") and not bool(result2["ok"]), "box breaker: 3 missed balls loses")
	game2.queue_free()

	# Jackpot line at the back wins the run instantly.
	var bbscr = load("res://scripts/minigames/amazon_break.gd")
	_check(int(bbscr.BOX_ROWS) == 2, "box breaker: 2 rows of boxes")
	var game3 = bbscr.new()
	game3.size = Vector2(700, 560)
	root.add_child(game3)
	var result3 := {}
	game3.finished.connect(func(success: bool) -> void: result3["ok"] = success)
	game3.start()
	game3.test_hit_jackpot()
	await create_timer(1.6).timeout  # banner beat, then the frame detects the line
	_check(result3.has("ok") and bool(result3["ok"]), "box breaker: jackpot line wins instantly")
	game3.queue_free()

	# --- FakeTok (phone) minigame ----------------------------------------------
	# A big arrow shows above the phone screen; press the matching arrow key.
	# 12 correct presses wins; wrong arrows don't count.
	var phone = load("res://scripts/minigames/phone_swipe.gd").new()
	phone.size = Vector2(700, 560)
	root.add_child(phone)
	var presult := {}
	phone.finished.connect(func(success: bool) -> void: presult["ok"] = success)
	phone.start()
	# Force a known prompt before every press — never rely on the random
	# re-roll between presses, and pin the comments state explicitly.
	phone.test_set_prompt(KEY_UP)
	phone.test_press(KEY_UP)
	_check(int(phone.get("_hits")) == 1, "faketok: correct arrow counts")
	phone.test_set_prompt(KEY_DOWN)
	phone.test_press(KEY_LEFT)
	_check(int(phone.get("_hits")) == 1, "faketok: wrong arrow doesn't count")
	# Left/right toggle the comments.
	phone.set("_comments_open", false)
	phone.test_set_prompt(KEY_RIGHT)
	phone.test_press(KEY_RIGHT)
	_check(bool(phone.get("_comments_open")), "faketok: right opens comments")
	phone.test_set_prompt(KEY_LEFT)
	phone.test_press(KEY_LEFT)
	_check(not bool(phone.get("_comments_open")), "faketok: left closes comments")
	# Down goes to the next display (comments closed so it navigates).
	phone.set("_comments_open", false)
	var idx0: int = int(phone.get("_display_index"))
	phone.test_set_prompt(KEY_DOWN)
	phone.test_press(KEY_DOWN)
	_check(int(phone.get("_display_index")) == (idx0 + 1) % 16,
		"faketok: down goes to the next display")
	# Up is never offered while on the first TikTok.
	phone.set("_display_index", 0)
	var saw_up := false
	for i in 50:
		phone.test_pick_prompt()
		if phone.get_prompt() == KEY_UP:
			saw_up = true
	_check(not saw_up, "faketok: up never offered on the first tiktok")
	# Play to a win.
	var guard := 0
	while int(phone.get("_hits")) < 12 and guard < 60:
		phone.test_press(phone.get_prompt())
		guard += 1
	_check(presult.has("ok") and bool(presult["ok"]), "faketok: 12 correct swipes wins")
	phone.queue_free()

	# --- Trash Sort minigame -------------------------------------------------
	# Multiple items fall at once; every press sorts the bottom item.
	var tscr = load("res://scripts/minigames/trash_sort.gd")
	_check(int(tscr.ITEM_COUNT) == 4, "trash sort: 4 items on screen")
	var trash = tscr.new()
	trash.size = Vector2(700, 560)
	root.add_child(trash)
	var tresult := {}
	trash.finished.connect(func(success: bool) -> void: tresult["ok"] = success)
	trash.start()
	_check(int((trash.get("_items") as Array).size()) == 4, "trash sort: starts with 4 items")
	for i in 10:
		trash.test_sort_correct()
	_check(int(trash.get("_sorted")) == 10, "trash sort: 10 correct sorted")
	await create_timer(1.6).timeout
	_check(tresult.has("ok") and bool(tresult["ok"]), "trash sort: 10 correct wins")
	trash.queue_free()
	var trash2 = tscr.new()
	trash2.size = Vector2(700, 560)
	root.add_child(trash2)
	var tresult2 := {}
	trash2.finished.connect(func(success: bool) -> void: tresult2["ok"] = success)
	trash2.start()
	for i in 3:
		trash2.test_sort_wrong()
	await create_timer(1.6).timeout
	_check(tresult2.has("ok") and not bool(tresult2["ok"]), "trash sort: 3 mistakes loses")
	trash2.queue_free()

	# --- 100 cortisol rule ----------------------------------------------------
	if mode_name == "meltdown":
		var m = gs.get("mode_hook")
		var lives0: int = m.get("sanity_lives")
		var s_before: float = gs.serotonin
		gs.add_cortisol(1000.0)
		await _frames(5)
		# Meltdown intercepts the standard rule with its own signature flow:
		# sanity life lost, cortisol vented, day restarts — serotonin NOT zeroed.
		_check(m.get("sanity_lives") == lives0 - 1, "meltdown: loses a sanity life")
		_check(absf(gs.cortisol - 40.0) < 0.01, "meltdown: cortisol vents to 40")
		_check(absf(gs.serotonin - s_before) < 0.01,
			"meltdown: standard zero-serotonin rule did NOT fire")
		_check(String(gs.get_day_summary().get("end_reason", "")) == "",
			"meltdown: no standard cortisol day-end recorded")
	else:
		gs.add_cortisol(1000.0)
		await _frames(5)
		_check(not gs.sim_running, "100 cortisol ends the day")
		_check(gs.serotonin == 0.0, "day ends with zero serotonin")
		_check(String(gs.get_day_summary().get("end_reason", "")) == "cortisol",
			"day summary flags the cortisol ending")

	print("----")
	print("checks: %d  failures: %d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
