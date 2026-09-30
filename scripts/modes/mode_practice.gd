extends Node
## PRACTICE mode node. A child of the GameState autoload (GameState adds it
## as `mode_hook`); GameState queries the optional hook methods below and
## otherwise runs the base sim untouched.
##
## The safe sandbox and the game's front door — always unlocked:
## - NO CORTISOL: neglect pressure zeroed AND every cortisol gain zeroed, so
##   the stress meter can never climb. The day can't be cut short.
## - ALL MINIGAMES OPEN: every chore/fun station plays its minigame on E,
##   task or no task. Stations never dim.
## - ONE BIRD: the robin is out every day, touchable once EVER (+50
##   serotonin cap, banked forever).
## - THE LAPTOP (scripts/modes/store_practice.gd): WORK tab turns serotonin
##   into dollars (-10 serotonin, +$10 per verdict, same as night-shift);
##   the AMAZON tab sells the CLASSIC MODE unlock ($500) plus the same
##   6-product catalog as Cortisol Mode. Buying the unlock puts it on the
##   main menu forever.
## - ALL TASKS OPEN AT DAWN: every chore task opens the moment the day
##   starts and stays open all day — the task list is a full checklist.
##   No random procs, no re-procs: done stays done.
## - ENDLESS: the 7-day run limit doesn't apply — the sandbox never ends,
##   and dollars still sweep to savings at each day end.
##
## Godot conventions:
## - get_parent() is the GameState autoload (it added us). We read/write its
##   sim vars directly — it's our owner, so this coupling is intentional.


signal buffs_changed

const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")

## In-run upgrade tiers bought from the practice laptop's AMAZON tab.
## Same shelf as Cortisol Mode (mirrors its run_tier/buy_run_upgrade);
## permanent tiers live in GameState.
var run_upgrades: Dictionary = {}


func mode_id() -> int:
	return ModeManager.Mode.PRACTICE


func hud_tag() -> String:
	return "☀️ SEROTONIN"


func neglect_cortisol_rate() -> float:
	# Open tasks push nothing in the sandbox.
	return 0.0


func cortisol_multiplier() -> float:
	# Every cortisol GAIN (Luke, trades, fails) is zeroed too. Belt and
	# suspenders with neglect_cortisol_rate() above.
	return 0.0


func minigames_always_open() -> bool:
	# Every station's minigame is playable on E, no open task required.
	return true


func open_all_tasks_at_dawn() -> bool:
	# Every chore task opens the moment the day starts — full checklist.
	return true


func disable_task_procs() -> bool:
	# No random procs and no re-procs: done stays done all day.
	return true


func endless_run() -> bool:
	# The sandbox never ends: no 7-day run limit, dollars sweep daily.
	return true


func reset_run() -> void:
	## Called by GameState.new_run(): clear run-long state.
	run_upgrades.clear()


func run_tier(id: String) -> int:
	## This run's tier for an upgrade (0 = not bought this run).
	return int(run_upgrades.get(id, 0))


func buy_run_upgrade(id: String) -> Dictionary:
	## Spend DOLLARS on the next in-run tier. The tier is QUEUED, not
	## activated: it takes effect when a Box Breaker win delivers it. The
	## purchase opens the Amazon-box task (one task per any number of orders).
	## (Mirrors Cortisol Mode's shelf — the practice laptop sells the same
	## 6-product catalog.)
	var gs := get_parent()
	var def := _UPGRADE_DEFS.def(id)
	if def.is_empty():
		return {"ok": false, "msg": "Unknown item?!"}
	# Pending (undelivered) tiers count toward progression: the next tier
	# for sale is active + queued, so you can't order the same tier twice.
	var cur := run_tier(id) + int(gs.call("pending_count", id))
	if cur >= _UPGRADE_DEFS.max_tier():
		return {"ok": false, "msg": "Already maxed!"}
	var perm := 0
	if gs.has_method("permanent_tier"):
		perm = int(gs.call("permanent_tier", id))
	if perm >= cur + 1:
		return {"ok": false, "msg": "Your permanent T%d already covers this!" % perm}
	var tier_def: Dictionary = (def["tiers"] as Array)[cur]
	var cost := float(tier_def["run_cost"])
	if gs.dollars < cost:
		return {"ok": false, "msg": "Need $%d" % int(cost)}
	gs.add_dollars(-cost)
	gs.call("queue_order", id)
	return {"ok": true, "msg": "Ordered! 📦 Break down the Amazon boxes to get your %s." % String(tier_def["label"])}


func deliver_order(id: String) -> int:
	## A Box Breaker win delivers one queued tier: it takes effect now.
	run_upgrades[id] = int(run_upgrades.get(id, 0)) + 1
	buffs_changed.emit()
	return int(run_upgrades[id])


func day_summary_extras() -> Dictionary:
	return {"extra_lines": "Practice day complete — the robin is a one-time collectible (+50 serotonin cap, once ever) — and work the laptop to save up for Cortisol Mode (Dopamine Mode unlocks in the Cortisol store)!"}
