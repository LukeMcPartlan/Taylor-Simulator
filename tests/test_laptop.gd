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
	hook.set("owned_amazon", [])
	hook.set("owned_buffs", [])
	GS.set("dollars", 0.0)
	GS.set("day_number", 0)
	GS.start_new_day()
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

	# AMAZON tab: buy the big sponge ($30).
	GS.add_dollars(200.0)
	var d1: float = GS.get("dollars")
	var res: Dictionary = store.buy_row("amazon", "sponge")
	_check(bool(res.get("ok", false)), "amazon: bought the big sponge")
	_check(bool(m.call("owns_amazon_item", "sponge")), "amazon: sponge owned")
	_check(absf(float(GS.get("dollars")) - (d1 - 30.0)) < 0.01, "amazon: $30 deducted")
	var res2: Dictionary = store.buy_row("amazon", "sponge")
	_check(not bool(res2.get("ok", false)), "amazon: one per game")

	# Buy the rest of the inventory.
	for id in ["moon_shoes", "extra_ball", "pipes", "paddle", "hamper"]:
		var r: Dictionary = store.buy_row("amazon", id)
		_check(bool(r.get("ok", false)), "amazon: bought " + id)
	GS.add_dollars(100.0)
	var rr: Dictionary = store.buy_row("amazon", "roomba")
	_check(bool(rr.get("ok", false)), "amazon: bought the roomba")
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

	# Buff hooks in the minigames.
	var mw = load("res://scripts/minigames/microwave_wipe.gd").new()
	mw.size = Vector2(700, 560)
	root.add_child(mw)
	mw.start()
	_check(absf(float(mw.get("_brush_radius")) - 51.0) < 0.01, "big sponge: brush 34 -> 51")
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

	print("checks: ", _checks, "  failures: ", _failures.size())
	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
