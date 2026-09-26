extends SceneTree
## Headless test for the Cortisol Mode laptop catalog (2026-09-26):
##  - the same laptop hardware opens in Cortisol Mode (walk-up, always open)
##  - AMAZON tab sells Cortisol Mode's own 6-product catalog
##  - purchases work (in-run tiers) and permanent tiers apply in every mode
##  - Lucky Diapers: bonus good-item spawns never change the gross rate
##  - Steady Hands: wider green zone in Spoon Timing
##  - Moon Shoes: hold-to-charge jump; tap is the normal hop
##
## Run: godot --headless --script tests/test_cortisol_catalog.gd
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
	MM.set_mode(0)  # CLASSIC (Cortisol Mode)
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	GS.add_child(hook)
	GS.set("mode_hook", hook)
	hook.set("run_upgrades", {})
	GS.set("permanent_upgrades", {})
	GS.set("savings", 0.0)
	GS.set("dollars", 0.0)
	GS.set("day_number", 0)
	GS.start_new_day()
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
	var m = GS.get("mode_hook")
	_check(m != null, "cortisol mode node exists (no longer null)")
	_check(int(m.call("mode_id")) == 0, "mode node reports CLASSIC")

	# The same laptop hardware, in Cortisol Mode.
	var store = _find_store(world)
	_check(store != null, "laptop store exists in cortisol world")
	_check(int(store.call("_store_mode_id")) == 0, "laptop serves cortisol mode")
	_check(bool(store.call("is_open")), "laptop open at 6am in cortisol mode")

	# Cortisol Mode's own 6-product catalog.
	var rows: Array = store.call("get_rows")
	var ids: Array = []
	for row in rows:
		ids.append(String(row["id"]))
	_check(ids.slice(0, 6) == ["extra_ball", "sponge", "pipes", "good_drops", "green_zone", "moon_shoes"],
		"cortisol catalog: exactly the 6 products, in order")
	_check(String(rows[6]["kind"]) == "unlock" and String(rows[6]["id"]) == "dopamine",
		"cortisol row 7 is the dopamine-mode unlock")
	# Main-menu product progress counts the catalog.
	var prog: Array = GS.call("product_progress", 0)
	_check(int(prog[0]) == 0 and int(prog[1]) == 6, "product progress 0/6 before buying")

	# Buying in-run tiers with dollars.
	GS.set("dollars", 500.0)
	var r1: Dictionary = store.call("buy_row", "upgrade", "good_drops")
	_check(bool(r1.get("ok", false)), "bought Lucky Diapers T1")
	_check(int(m.call("run_tier", "good_drops")) == 1, "good_drops run tier 1")
	_check(absf(float(GS.get("dollars")) - 460.0) < 0.01, "good_drops T1 cost $40")
	var r2: Dictionary = store.call("buy_row", "upgrade", "green_zone")
	_check(bool(r2.get("ok", false)), "bought Steady Hands T1")
	_check(int(GS.call("upgrade_tier", "green_zone")) == 1, "effective tier via GameState")
	var prog2: Array = GS.call("product_progress", 0)
	_check(int(prog2[0]) == 2, "product progress 2/6 after buying two")

	# Permanent tiers apply in EVERY mode (bought in the main-menu savings shop).
	GS.set("savings", 1000.0)
	var bp: Dictionary = GS.call("buy_permanent_upgrade", "moon_shoes")
	_check(bool(bp.get("ok", false)), "permanent: bought Moon Shoes T1 with savings")
	_check(int(GS.call("upgrade_tier", "moon_shoes")) == 1, "effective moon_shoes T1 in cortisol")
	# Switch to night-shift: the permanent tier is still there.
	MM.set_mode(1)
	var old2 = GS.get("mode_hook")
	GS.remove_child(old2)
	old2.free()
	GS.set("mode_hook", null)
	var hook2 = MM.create_mode()
	GS.add_child(hook2)
	GS.set("mode_hook", hook2)
	hook2.set("run_upgrades", {})
	_check(int(GS.call("upgrade_tier", "moon_shoes")) == 1,
		"permanent moon_shoes applies in night-shift too")

	# Lucky Diapers: the gross-item rate is untouched (0.65), bonus spawns are
	# goods only.
	var dc = load("res://scripts/minigames/diaper_catch.gd").new()
	_check(absf(DiaperCatch.GROSS_CHANCE - 0.65) < 0.001, "diaper catch: gross chance still 0.65")
	dc.size = Vector2(700, 560)
	root.add_child(dc)
	dc.start()
	_check(absf(float(dc.call("_bonus_good_chance"))) < 0.001, "no bonus spawns at tier 0")
	# Tier 3 via the (cortisol) run shelf: swap the hook back first.
	MM.set_mode(0)
	var old3 = GS.get("mode_hook")
	GS.remove_child(old3)
	old3.free()
	GS.set("mode_hook", null)
	var hook3 = MM.create_mode()
	GS.add_child(hook3)
	GS.set("mode_hook", hook3)
	hook3.set("run_upgrades", {"good_drops": 3})
	_check(absf(float(dc.call("_bonus_good_chance")) - 0.8) < 0.001, "bonus chance 0.8 at T3")
	seed(12345)
	var kinds_seen := {}
	for i in 80:
		var before: int = (dc.get("_items") as Array).size()
		dc.call("_spawn_bonus_good")
		var items: Array = dc.get("_items")
		if items.size() > before:
			kinds_seen[String((items[items.size() - 1] as Dictionary)["kind"])] = true
	var gross_kinds: Array = DiaperCatch.GROSS_KINDS
	var saw_gross := false
	for k in kinds_seen.keys():
		if k in gross_kinds:
			saw_gross = true
	_check(not kinds_seen.is_empty(), "bonus spawns actually drop items")
	_check(not saw_gross, "bonus spawns are never gross items")
	dc.queue_free()

	# Steady Hands: wider green zone in Spoon Timing.
	var bs = load("res://scripts/minigames/baby_spoon.gd").new()
	bs.size = Vector2(700, 560)
	root.add_child(bs)
	bs.start()
	hook3.set("run_upgrades", {"green_zone": 0})
	_check(absf(float(bs.call("_zone_w")) - 110.0) < 0.01, "green zone 110 wide at tier 0")
	hook3.set("run_upgrades", {"green_zone": 2})
	_check(absf(float(bs.call("_zone_w")) - 176.0) < 0.01, "green zone 176 wide at T2 (1.6x)")
	bs.queue_free()

	# Moon Shoes: hold to charge; a tap is the normal hop, a full charge at
	# T1 is 1.6x.
	var taylor = world.get_tree().get_nodes_in_group("player")[0]
	hook3.set("run_upgrades", {"moon_shoes": 0})
	GS.set("permanent_upgrades", {})
	_check(absf(float(taylor.call("_charged_jump_velocity", 0.0)) - (-400.0)) < 0.01,
		"no shoes: tap is the normal -400 hop")
	_check(absf(float(taylor.call("_charged_jump_velocity", 1.0)) - (-400.0)) < 0.01,
		"no shoes: holding jump does nothing special")
	hook3.set("run_upgrades", {"moon_shoes": 1})
	_check(absf(float(taylor.call("_charged_jump_velocity", 0.0)) - (-400.0)) < 0.01,
		"moon shoes T1: uncharged jump still -400")
	_check(absf(float(taylor.call("_charged_jump_velocity", 1.0)) - (-640.0)) < 0.01,
		"moon shoes T1: full charge -> -640")
	hook3.set("run_upgrades", {"moon_shoes": 3})
	_check(absf(float(taylor.call("_charged_jump_velocity", 1.0)) - (-1080.0)) < 0.01,
		"moon shoes T3: full charge -> -1080")

	# Hold-S fast-forward is a base mechanic: documented in the help text.
	var dc2 = load("res://scripts/minigames/diaper_catch.gd").new()
	dc2.size = Vector2(700, 560)
	root.add_child(dc2)
	dc2.start()
	_check(String(dc2.get("help_text")).contains("Hold S"),
		"diaper catch help documents hold-S fast-forward")
	dc2.queue_free()

	# Restore the real savings file the test borrowed.
	if _bank_backup.is_empty():
		if FileAccess.file_exists("user://taylor_savings.cfg"):
			DirAccess.remove_absolute("user://taylor_savings.cfg")
	else:
		var f := FileAccess.open("user://taylor_savings.cfg", FileAccess.WRITE)
		f.store_buffer(_bank_backup)
		f.close()

	if _failures.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _failures)
	quit(1 if not _failures.is_empty() else 0)
