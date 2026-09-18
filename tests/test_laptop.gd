extends SceneTree
## Headless integration test for the night-shift laptop rework (2026-09-18):
##  - laptop store exists, open at any hour, clock keeps ticking
##  - WORK: FIRE/HIRE costs 10 serotonin, pays $10, new email each press
##  - AMAZON: dollars buy one-per-game buffs
##  - Roomba spawns on purchase and vacuums garbage
##  - buff hooks: moon shoes, big sponge, stronger pipes, extra ball,
##    paddle extender, hamper magnets
##
## Run: godot --headless --script tests/test_laptop.gd
##
## NOTE: bare autoload names do not resolve when a script is compiled as the
## --script main loop, so singletons are looked up as untyped vars.

var _failures: Array = []
var _checks: int = 0
var GS = null
var MM = null
var _bank_backup: PackedByteArray = PackedByteArray()


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
	MM.set_mode(1)  # NIGHT_SHIFT
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	GS.add_child(hook)
	GS.set("mode_hook", hook)
	hook.set("run_upgrades", {})
	hook.set("owned_buffs", [])
	GS.set("permanent_upgrades", {})
	GS.set("savings", 0.0)
	GS.set("dollars", 0.0)
	GS.set("day_number", 0)
	GS.start_new_day()
	# Back up the real savings file — the test buys permanent upgrades.
	if FileAccess.file_exists("user://taylor_savings.cfg"):
		_bank_backup = FileAccess.get_file_as_bytes("user://taylor_savings.cfg")
	var scene: PackedScene = load("res://Main.tscn")
	root.add_child(scene.instantiate())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _find_store(world: Node):
	for n in world.get_children():
		if n.has_method("store_title") and String(n.call("store_title")).contains("LAPTOP"):
			return n
	return null


func _run_tests() -> void:
	await _frames(10)
	var world = root.get_node("Main/World")
	_check(world != null, "world exists")
	var store = _find_store(world)
	_check(store != null, "laptop store exists in night-shift world")
	var m = GS.get("mode_hook")

	# Open at any hour (old store was 9pm-11pm).
	_check(bool(store.call("is_open")), "laptop open at 6am")
	GS.set("time_hours", 15.0)
	await _frames(3)
	_check(bool(store.call("is_open")), "laptop still open at 3pm")

	# WORK tab: FIRE costs 10 serotonin, pays $10.
	GS.set("serotonin", 60.0)
	GS.set("dollars", 0.0)
	store._do_work("FIRED")
	_check(absf(float(GS.get("serotonin")) - 50.0) < 0.01, "work: -10 serotonin")
	_check(absf(float(GS.get("dollars")) - 10.0) < 0.01, "work: +$10")
	store._do_work("HIRED")
	_check(absf(float(GS.get("dollars")) - 20.0) < 0.01, "work: hire also pays $10")
	# Too dead inside to manage.
	GS.set("serotonin", 5.0)
	var d0: float = GS.get("dollars")
	store._do_work("FIRED")
	_check(absf(float(GS.get("dollars")) - d0) < 0.01, "work: blocked under 10 serotonin")

	# UPGRADE tab: tiered purchases with dollars — in-run only.
	GS.add_dollars(200.0)
	var d1: float = GS.get("dollars")
	var res: Dictionary = store.buy_row("upgrade", "sponge")
	_check(bool(res.get("ok", false)), "upgrade: bought sponge T1")
	_check(int(m.call("run_tier", "sponge")) == 1, "upgrade: sponge run tier 1")
	_check(absf(float(GS.get("dollars")) - (d1 - 30.0)) < 0.01, "upgrade: $30 deducted")
	# Tiers 2 ($60) and 3 ($120), then maxed.
	var res2: Dictionary = store.buy_row("upgrade", "sponge")
	_check(bool(res2.get("ok", false)), "upgrade: bought sponge T2")
	_check(int(m.call("run_tier", "sponge")) == 2, "upgrade: sponge run tier 2")
	GS.add_dollars(200.0)
	var res3: Dictionary = store.buy_row("upgrade", "sponge")
	_check(bool(res3.get("ok", false)), "upgrade: bought sponge T3")
	_check(int(m.call("run_tier", "sponge")) == 3, "upgrade: sponge run tier 3")
	var res4: Dictionary = store.buy_row("upgrade", "sponge")
	_check(not bool(res4.get("ok", false)), "upgrade: T3 is maxed")

	# Buy the rest of the gadget inventory at T1.
	for id in ["moon_shoes", "extra_ball", "pipes", "paddle", "hamper"]:
		var r: Dictionary = store.buy_row("upgrade", id)
		_check(bool(r.get("ok", false)), "upgrade: bought " + id + " T1")
	GS.add_dollars(100.0)
	var rr: Dictionary = store.buy_row("upgrade", "roomba")
	_check(bool(rr.get("ok", false)), "upgrade: bought the roomba")
	await _frames(5)
	var roombas: Array = world.get_tree().get_nodes_in_group("roomba")
	_check(roombas.size() == 1, "roomba spawned in the world")

	# Roomba vacuums garbage on touch (no cortisol relief for robots).
	var g = load("res://scripts/garbage.gd").new()
	world.add_child(g)
	g.global_position = (roombas[0] as Node2D).global_position + Vector2(10, 0)
	var c0: float = GS.get("cortisol")
	await _frames(10)
	_check(not is_instance_valid(g), "roomba vacuumed the garbage")
	# (tolerance: background neglect drifts cortisol a little while we watch)
	_check(absf(float(GS.get("cortisol")) - c0) < 0.5, "roomba: no cortisol change")

	# Buff hooks in the minigames (sponge is T3: brush 34 * 2.5).
	var mw = load("res://scripts/minigames/microwave_wipe.gd").new()
	mw.size = Vector2(700, 560)
	root.add_child(mw)
	mw.start()
	_check(absf(float(mw.get("_brush_radius")) - 85.0) < 0.01, "the spongenator: brush 34 -> 85")
	mw.queue_free()
	var tw = load("res://scripts/minigames/toilet_whack.gd").new()
	tw.size = Vector2(700, 560)
	root.add_child(tw)
	tw.start()
	_check(absf(float(tw.get("_spread_interval")) - 4.0) < 0.01, "stronger pipes: spread 2s -> 4s")
	tw.queue_free()
	var ab = load("res://scripts/minigames/amazon_break.gd").new()
	ab.size = Vector2(700, 560)
	root.add_child(ab)
	ab.start()
	_check(int(ab.call("_ball_count")) == 2, "extra hand: 2 balls in play")
	_check(absf(float(ab.get("_pw")) - 168.0) < 0.01, "paddle extender: 120 -> 168 wide")
	ab.queue_free()
	var lh = load("res://scripts/minigames/laundry_hoops.gd").new()
	lh.size = Vector2(700, 560)
	root.add_child(lh)
	lh.start()
	_check(absf((lh.get("_hamper") as Rect2).size.x - 150.0) < 0.01, "hamper magnets: wider hamper")
	lh.queue_free()

	# Moon shoes: Taylor jumps 35% higher.
	var taylor = world.get_tree().get_nodes_in_group("player")[0]
	_check(absf(float(taylor.call("_jump_velocity")) - (-540.0)) < 0.01,
		"moon shoes: jump -400 -> -540")

	# Collectibles raise the serotonin cap.
	_check(absf(float(GS.call("get_serotonin_cap")) - 200.0) < 0.01, "cap: base 200")
	GS.add_dollars(100.0)
	var rc: Dictionary = store.buy_row("upgrade", "raquaza")
	_check(bool(rc.get("ok", false)), "upgrade: bought the shiny raquaza card")
	_check(absf(float(GS.call("get_serotonin_cap")) - 250.0) < 0.01, "cap: raquaza T1 -> 250")
	GS.set("serotonin", 0.0)
	GS.add_serotonin(500.0)
	_check(absf(float(GS.get("serotonin")) - 250.0) < 0.01, "cap: serotonin clamps at 250")

	# Savings: permanent upgrades bought with savings, indestructible.
	GS.set("savings", 500.0)
	var bp: Dictionary = GS.call("buy_permanent_upgrade", "sponge")
	_check(bool(bp.get("ok", false)), "permanent: bought sponge T1 with savings")
	_check(int(GS.call("permanent_tier", "sponge")) == 1, "permanent: sponge tier 1")
	_check(absf(float(GS.get("savings")) - 400.0) < 0.01, "permanent: $100 spent")
	_check(int(GS.call("upgrade_tier", "sponge")) == 3, "effective: run T3 beats perm T1")
	_check(int(GS.call("upgrade_tier", "hamper")) == 1, "effective: run-only hamper T1")
	# Permanent T2 hamper covers run T1: buying run T2 is pointless, blocked.
	GS.call("buy_permanent_upgrade", "hamper")
	GS.call("buy_permanent_upgrade", "hamper")
	_check(int(GS.call("permanent_tier", "hamper")) == 2, "permanent: hamper T2")
	var blocked: Dictionary = store.buy_row("upgrade", "hamper")
	_check(not bool(blocked.get("ok", false)), "upgrade: run tier blocked, permanent covers it")

	# Day-end sweep: leftover dollars move into savings.
	GS.set("dollars", 37.0)
	var s0: float = GS.get("savings")
	GS.call("sweep_to_savings")
	_check(absf(float(GS.get("dollars"))) < 0.01, "sweep: dollars zeroed")
	_check(absf(float(GS.get("savings")) - (s0 + 37.0)) < 0.01, "sweep: savings grew by $37")

	# New run wipes run tiers; permanent tiers survive.
	GS.call("new_run")
	_check(int(m.call("run_tier", "sponge")) == 0, "new run: run tiers wiped")
	_check(int(GS.call("permanent_tier", "sponge")) == 1, "new run: permanent tiers kept")
	_check(int(GS.call("upgrade_tier", "sponge")) == 1, "new run: effective falls back to permanent")

	# Restore the real savings file the test borrowed.
	if _bank_backup.is_empty():
		if FileAccess.file_exists("user://taylor_savings.cfg"):
			DirAccess.remove_absolute("user://taylor_savings.cfg")
	else:
		var f := FileAccess.open("user://taylor_savings.cfg", FileAccess.WRITE)
		f.store_buffer(_bank_backup)
		f.close()
	GS.call("load_bank")

	print("checks: ", _checks, "  failures: ", _failures.size())
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
