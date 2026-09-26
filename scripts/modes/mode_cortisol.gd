extends Node
## CORTISOL MODE node (the base game). A child of the GameState autoload;
## GameState queries the optional hook methods below and otherwise runs the
## base sim untouched.
##
## Cortisol Mode adds no gameplay overrides — the base sim IS this mode. The
## node exists so the laptop (scripts/modes/store_cortisol.gd) has a run-tier
## upgrade shelf: dollars buy in-run tiers, permanent tiers live in GameState.
##
## Godot conventions:
## - get_parent() is the GameState autoload (it added us). We read/write its
##   sim vars directly — it's our owner, so this coupling is intentional.

signal buffs_changed

const _UPGRADE_DEFS = preload("res://scripts/upgrade_defs.gd")

## In-run upgrade tiers: upgrade id -> tier (1-3). Bought with dollars at the
## laptop; lasts the RUN only. Permanent tiers live in GameState.
var run_upgrades: Dictionary = {}


func mode_id() -> int:
	return ModeManager.Mode.CLASSIC


func reset_run() -> void:
	## Called by GameState.new_run(): clear run-long state.
	run_upgrades.clear()  # in-run tiers last the run; permanent tiers live in GameState


func run_tier(id: String) -> int:
	## This run's tier for an upgrade (0 = not bought this run).
	return int(run_upgrades.get(id, 0))


func buy_run_upgrade(id: String) -> Dictionary:
	## Spend DOLLARS on the next in-run tier. Lasts the run only.
	var gs := get_parent()
	var def := _UPGRADE_DEFS.def(id)
	if def.is_empty():
		return {"ok": false, "msg": "Unknown item?!"}
	var cur := run_tier(id)
	if cur >= _UPGRADE_DEFS.max_tier():
		return {"ok": false, "msg": "Already maxed!"}
	# No point buying an in-run tier your permanent collection already covers.
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
	run_upgrades[id] = cur + 1
	buffs_changed.emit()
	return {"ok": true, "msg": "Delivered! %s" % String(tier_def["label"])}
