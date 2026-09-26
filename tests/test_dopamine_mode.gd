extends SceneTree
## Headless test for Dopamine Mode + the bird-cap + 7-day money/run rework
## (2026-09-26):
##  - Mode.DOPAMINE is id 6; ids are stable (no renumbering)
##  - dopamine drains 5x in Dopamine Mode, 1x everywhere else
##  - Dopamine Mode is bought for $100 in the practice store, unlocks the
##    main-menu card, and uses the same laptop + 6-product catalog as Cortisol
##  - one fixed bird is active per mode (dopamine's is the robin)
##  - collecting a bird raises the serotonin cap by 50 (no instant serotonin)
##  - dollars persist across days; they sweep to savings only at run end
##  - runs end after 7 days (run-over panel, dollars swept)
##  - cortisol/dopamine/past-bedtime losses WIPE in-run dollars; savings kept
##  - practice is endless: no run-over on day 7, daily sweep kept
##
## Run: godot --headless --script tests/test_dopamine_mode.gd
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


func _set_mode(mode: int) -> void:
	MM.set_mode(mode)
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	GS.add_child(hook)
	GS.set("mode_hook", hook)


func _fresh_day() -> void:
	# A clean non-run day 1 in the current mode, no money moved.
	GS.set("day_number", 0)
	GS.set("dollars", 0.0)
	GS.set("cortisol", 10.0)
	GS.set("serotonin", 100.0)
	GS.set("dopamine", 100.0)
	GS.start_new_day()


func _run_tests() -> void:
	# Snapshot the player's real bank state — several tests earn, sweep,
	# and collect, and must not leave fingerprints in the save file.
	var real_dollars: float = GS.get("dollars")
	var real_savings: float = GS.get("savings")
	var real_birds: Array = (GS.get("birds_found") as Array).duplicate()
	_test_mode_id_stable()
	_test_dopamine_drain_mult()
	_test_dopamine_drain_5x_integration()
	_test_store_unlock()
	_test_dopamine_catalog()
	_test_bird_per_mode()
	_test_bird_cap_reward()
	_test_money_persists_across_days()
	_test_seven_day_run_end()
	_test_loss_wipes_dollars()
	_test_practice_endless()
	GS.set("dollars", real_dollars)
	GS.set("savings", real_savings)
	GS.set("birds_found", real_birds)
	GS.save_bank()
	print("----")
	print("checks: %d, failures: %d" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("ALL GREEN")
		quit(0)
	else:
		print("FAILURES:")
		for f in _failures:
			print("  - ", f)
		quit(1)


# ---------------------------------------------------------------- mode id

func _test_mode_id_stable() -> void:
	_check(MM.Mode.DOPAMINE == 6, "dopamine mode id is 6")
	_check(MM.Mode.CLASSIC == 0, "classic still id 0")
	_check(MM.Mode.PRACTICE == 5, "practice still id 5")
	var scripts: Dictionary = MM.get("MODE_SCRIPTS")
	_check(String(scripts.get(6, "")).ends_with("mode_dopamine.gd"),
		"mode 6 loads mode_dopamine.gd")


# ---------------------------------------------------------------- drain

func _test_dopamine_drain_mult() -> void:
	_set_mode(6)
	_check(absf(GS._dopamine_drain_mult() - 5.0) < 0.001,
		"dopamine mode drain mult is 5.0")
	_set_mode(0)
	_check(absf(GS._dopamine_drain_mult() - 1.0) < 0.001,
		"classic mode drain mult is 1.0")


func _test_dopamine_drain_5x_integration() -> void:
	# One real game-hour through _process: dopamine drops 5x in dopamine mode.
	_set_mode(6)
	_fresh_day()
	GS.set("dopamine", 100.0)
	GS.set("sim_running", true)
	GS._process(GS.get_seconds_per_game_hour())
	var d_after: float = GS.get("dopamine")
	_check(absf(d_after - 80.0) < 0.5,
		"dopamine drops 20/game-hour in dopamine mode (got %.1f)" % d_after)
	_set_mode(0)
	_fresh_day()
	GS.set("dopamine", 100.0)
	GS.set("sim_running", true)
	GS._process(GS.get_seconds_per_game_hour())
	var c_after: float = GS.get("dopamine")
	_check(absf(c_after - 96.0) < 0.5,
		"dopamine drops 4/game-hour in classic mode (got %.1f)" % c_after)


# ---------------------------------------------------------------- unlock

func _test_store_unlock() -> void:
	_set_mode(5)  # practice store sells the unlocks
	# Snapshot the real unlock list — the test buys modes and must not
	# permanently unlock them in the player's bank file.
	var real_unlocks: Array = (GS.get("unlocked_modes") as Array).duplicate()
	GS.get("unlocked_modes").erase(6)
	GS.get("unlocked_modes").erase(0)
	_check(not GS.is_mode_unlocked(6), "dopamine locked before purchase")
	var store = load("res://scripts/modes/store_practice.gd").new()
	var rows: Array = store.get_rows()
	_check(rows.size() == 2, "practice store lists 2 unlocks")
	_check(String(rows[0]["id"]) == "classic" and String(rows[0]["price"]) == "$60",
		"row 1 is cortisol mode $60")
	_check(String(rows[1]["id"]) == "dopamine" and String(rows[1]["price"]) == "$100",
		"row 2 is dopamine mode $100")
	var broke: Dictionary = store.buy_row("unlock", "dopamine")
	_check(not bool(broke.get("ok", false)), "dopamine unlock refused when broke")
	GS.add_dollars(100.0)
	var bought: Dictionary = store.buy_row("unlock", "dopamine")
	_check(bool(bought.get("ok", false)), "dopamine unlock bought for $100")
	_check(GS.is_mode_unlocked(6), "dopamine unlocked after purchase")
	_check(absf(GS.get("dollars")) < 0.01, "purchase took the $100")
	var again: Dictionary = store.buy_row("unlock", "dopamine")
	_check(not bool(again.get("ok", false)), "dopamine unlock not re-buyable")
	store.free()
	# Classic unlock still works and is independent.
	GS.set("dollars", 0.0)
	GS.add_dollars(60.0)
	var classic: Dictionary = load("res://scripts/modes/store_practice.gd").new().buy_row("unlock", "classic")
	_check(bool(classic.get("ok", false)), "classic unlock still buyable")
	_check(GS.is_mode_unlocked(0), "classic unlocked too")
	# Restore the player's real unlock list.
	GS.set("unlocked_modes", real_unlocks)
	GS.save_bank()


func _test_dopamine_catalog() -> void:
	# Same laptop hardware and 6-product catalog as cortisol mode.
	var store = load("res://scripts/modes/store_dopamine.gd").new()
	_check(store._store_mode_id() == 6, "dopamine store gates on mode 6")
	_set_mode(6)
	var d_rows: Array = store.get_rows()
	_set_mode(0)
	var cortisol_store = load("res://scripts/modes/store_cortisol.gd").new()
	var c_rows: Array = cortisol_store.get_rows()
	_check(d_rows.size() == 6 and c_rows.size() == 6,
		"dopamine and cortisol stores both sell 6 products")
	var same := true
	for i in d_rows.size():
		if String(d_rows[i].get("id", "")) != String(c_rows[i].get("id", "")):
			same = false
	_check(same, "dopamine catalog matches cortisol catalog product-for-product")
	var prods: Array = GS._UPGRADE_DEFS.products_for_mode(6)
	_check(prods.size() == 6, "upgrade_defs lists 6 products for mode 6")
	store.free()
	cortisol_store.free()


# ---------------------------------------------------------------- birds

func _test_bird_per_mode() -> void:
	var birds: Dictionary = GS.get("MODE_BIRDS")
	_check(birds.has(6), "mode 6 has a bird mapping")
	_set_mode(6)
	GS.get("birds_found").clear()
	_check(GS.bird_active_today("robin"), "robin active in dopamine mode")
	_check(not GS.bird_active_today("crow"), "crow not active in dopamine mode")
	_set_mode(0)
	_check(GS.bird_active_today("robin"), "robin active in classic mode")
	_check(not GS.bird_active_today("owl"), "owl not active in classic mode")


func _test_bird_cap_reward() -> void:
	GS.get("birds_found").clear()
	_set_mode(0)
	_check(absf(GS.get_serotonin_cap() - 200.0) < 0.01, "serotonin cap is 200 with no birds")
	GS.set("serotonin", 100.0)
	var first: bool = GS.collect_bird("robin")
	_check(first, "first robin touch collects")
	_check(absf(GS.get_serotonin_cap() - 250.0) < 0.01, "cap rises to 250 after one bird")
	_check(absf(GS.get("serotonin") - 100.0) < 0.01, "no instant serotonin from the bird")
	var dup: bool = GS.collect_bird("robin")
	_check(not dup, "second robin touch does not re-collect")
	_check(absf(GS.get_serotonin_cap() - 250.0) < 0.01, "cap unchanged by duplicate touch")
	GS.collect_bird("crow")
	_check(absf(GS.get_serotonin_cap() - 300.0) < 0.01, "cap rises 50 per species (300 after two)")
	_check(not GS.bird_active_today("robin"), "found robin no longer active in classic")
	_set_mode(5)
	_check(GS.bird_active_today("robin"), "found robin still visible in practice gallery")
	GS.get("birds_found").clear()


# ---------------------------------------------------------------- money

func _test_money_persists_across_days() -> void:
	_set_mode(0)
	_fresh_day()
	GS.set("savings", 10.0)
	GS.add_dollars(50.0)
	GS.start_new_day()  # day 2
	_check(absf(GS.get("dollars") - 50.0) < 0.01, "dollars carry across days ($50 kept)")
	_check(absf(GS.get("savings") - 10.0) < 0.01, "no daily sweep to savings anymore")


func _test_seven_day_run_end() -> void:
	_set_mode(0)
	var run_hits: Array = []
	GS.connect("run_ended", func(_t: String, _s: String, _k: String) -> void: run_hits.append(true))
	var day_hits: Array = []
	GS.connect("day_ended", func() -> void: day_hits.append(true))
	GS.set("day_number", 6)
	GS.set("dollars", 0.0)
	GS.set("savings", 0.0)
	GS.start_new_day()  # day 7
	GS.add_dollars(75.0)
	GS.go_to_bed()  # clean day end on day 7
	_check(run_hits.size() == 1, "day 7 end fires run_ended (not another day)")
	_check(day_hits.is_empty(), "day 7 end does not fire day_ended")
	_check(absf(GS.get("dollars")) < 0.01, "run end sweeps dollars to zero")
	_check(absf(GS.get("savings") - 75.0) < 0.01, "run end sweeps $75 to savings")
	# A fresh run starts clean at day 1 and can re-earn.
	GS.new_run()
	_check(GS.get("day_number") == 1, "new run starts at day 1")
	_check(absf(GS.get("savings") - 75.0) < 0.01, "savings kept across the new run")
	GS.add_dollars(20.0)
	_check(absf(GS.get("dollars") - 20.0) < 0.01, "new run earns fresh dollars")


func _test_loss_wipes_dollars() -> void:
	_set_mode(0)
	# Cortisol loss.
	_fresh_day()
	GS.set("savings", 40.0)
	GS.add_dollars(55.0)
	GS.set("cortisol", 100.0)
	GS.set("sim_running", true)
	GS._process(0.01)
	_check(absf(GS.get("dollars")) < 0.01, "cortisol loss wipes in-run dollars")
	_check(absf(GS.get("savings") - 40.0) < 0.01, "cortisol loss keeps savings")
	# Dopamine loss (dopamine mode drains 5x — 10 dopamine dies in one hour).
	_set_mode(6)
	_fresh_day()
	GS.set("savings", 40.0)
	GS.add_dollars(33.0)
	GS.set("dopamine", 10.0)
	GS.set("sim_running", true)
	GS._process(GS.get_seconds_per_game_hour())
	_check(absf(GS.get("dopamine")) < 0.01, "dopamine hit zero in dopamine mode")
	_check(absf(GS.get("dollars")) < 0.01, "dopamine loss wipes in-run dollars")
	_check(absf(GS.get("savings") - 40.0) < 0.01, "dopamine loss keeps savings")
	# Past-bedtime loss.
	_set_mode(0)
	_fresh_day()
	GS.add_dollars(21.0)
	GS.set("time_hours", 25.0)
	GS.set("sim_running", true)
	GS._process(0.01)
	_check(absf(GS.get("dollars")) < 0.01, "1 AM loss wipes in-run dollars")


func _test_practice_endless() -> void:
	_set_mode(5)
	var run_hits: Array = []
	GS.connect("run_ended", func(_t: String, _s: String, _k: String) -> void: run_hits.append(true))
	var day_hits: Array = []
	GS.connect("day_ended", func() -> void: day_hits.append(true))
	GS.set("day_number", 6)
	GS.set("dollars", 0.0)
	GS.set("savings", 0.0)
	GS.start_new_day()  # day 7
	GS.add_dollars(30.0)
	GS.go_to_bed()
	_check(day_hits.size() == 1, "practice day 7 end fires day_ended")
	_check(run_hits.is_empty(), "practice never fires run_ended")
	_check(absf(GS.get("dollars")) < 0.01, "practice keeps its daily sweep")
	_check(absf(GS.get("savings") - 30.0) < 0.01, "practice sweeps $30 to savings daily")
