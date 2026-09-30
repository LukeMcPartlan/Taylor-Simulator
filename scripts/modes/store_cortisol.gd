extends StoreLaptop
## Taylor's LAPTOP in Cortisol Mode: the same laptop hardware as every mode
## (WORK tab: deranged employee emails, FIRE/HIRE for dollars), but Cortisol
## Mode's AMAZON tab sells its own 6-product catalog:
##   Extra Ball (Box Breaker), Bigger Sponge (microwave),
##   Slower Leaks (toilet), Lucky Diapers (Diaper Catch good-item spawns),
##   Steady Hands (wider baby-feeding green zone), Moon Shoes (charge jump).
## Purchases are in-run tiers here; their effects apply in EVERY mode via
## GameState.upgrade_tier(), and permanent tiers are sold in the main menu.

const _CORTISOL_IDS: Array = [
	"extra_ball", "sponge", "pipes", "good_drops", "green_zone", "moon_shoes",
]

const DOPAMINE_PRICE: float = 500.0
const OXYTOCIN_PRICE: float = 500.0


func _store_mode_id() -> int:
	return ModeManager.Mode.CLASSIC


func _amazon_defs() -> Array:
	var defs: Array = []
	for pid in _CORTISOL_IDS:
		var d: Dictionary = _UPGRADE_DEFS.def(pid)
		if not d.is_empty():
			defs.append(d)
	return defs


func get_rows() -> Array:
	## The 6 products, plus — only in the REAL Cortisol store — the next
	## mode unlock: DOPAMINE MODE ($500). The REAL Dopamine store (this
	## script reporting _store_mode_id() == DOPAMINE) sells the one after
	## that: OXYTOCIN MODE ($500). (StoreDopamine/StoreOxytocin inherit
	## this script but never sell their own unlock.)
	var rows: Array = super.get_rows()
	var m := _mode()
	if m == null:
		return rows
	if _store_mode_id() == ModeManager.Mode.CLASSIC:
		var unlocked := GameState.is_mode_unlocked(ModeManager.Mode.DOPAMINE)
		rows.append({
			"number": rows.size() + 1, "kind": "unlock", "id": "dopamine",
			"section": "📦 AMAZON",
			"name": "Dopamine Mode — cortisol rules, dopamine drains 5x",
			"desc": "Order 📱 Dopamine Mode from Amazon. Same brutal chores, but the phone is life support. Forever.",
			"price": "$%d" % int(DOPAMINE_PRICE),
			"status": "OWNED" if unlocked else "",
			"affordable": (not unlocked) and GameState.dollars >= DOPAMINE_PRICE,
		})
	elif _store_mode_id() == ModeManager.Mode.DOPAMINE:
		var o_unlocked := GameState.is_mode_unlocked(ModeManager.Mode.OXYTOCIN)
		rows.append({
			"number": rows.size() + 1, "kind": "unlock", "id": "oxytocin",
			"section": "📦 AMAZON",
			"name": "Oxytocin Mode — send Luke to do your chores",
			"desc": "Order 💞 Oxytocin Mode from Amazon. Press Q near Luke and he teleports to a chore and does it. Forever.",
			"price": "$%d" % int(OXYTOCIN_PRICE),
			"status": "OWNED" if o_unlocked else "",
			"affordable": (not o_unlocked) and GameState.dollars >= OXYTOCIN_PRICE,
		})
	return rows


func buy_row(kind: String, id: String) -> Dictionary:
	if kind == "unlock" and id == "dopamine":
		if _store_mode_id() != ModeManager.Mode.CLASSIC:
			return {"ok": false, "msg": "Click a tab, boss."}
		if GameState.is_mode_unlocked(ModeManager.Mode.DOPAMINE):
			return {"ok": false, "msg": "Already unlocked!"}
		if GameState.dollars < DOPAMINE_PRICE:
			return {"ok": false, "msg": "Need $%d" % int(DOPAMINE_PRICE)}
		GameState.add_dollars(-DOPAMINE_PRICE)
		GameState.unlock_mode(ModeManager.Mode.DOPAMINE)
		GameState.say("TAYLOR", "PACKAGE DELIVERED! 📦 Dopamine Mode is on the main menu!")
		return {"ok": true, "msg": "📦 ORDER DELIVERED! 📱 DOPAMINE MODE UNLOCKED! Find it on the main menu."}
	if kind == "unlock" and id == "oxytocin":
		if _store_mode_id() != ModeManager.Mode.DOPAMINE:
			return {"ok": false, "msg": "Click a tab, boss."}
		if GameState.is_mode_unlocked(ModeManager.Mode.OXYTOCIN):
			return {"ok": false, "msg": "Already unlocked!"}
		if GameState.dollars < OXYTOCIN_PRICE:
			return {"ok": false, "msg": "Need $%d" % int(OXYTOCIN_PRICE)}
		GameState.add_dollars(-OXYTOCIN_PRICE)
		GameState.unlock_mode(ModeManager.Mode.OXYTOCIN)
		GameState.say("TAYLOR", "PACKAGE DELIVERED! 📦 Oxytocin Mode is on the main menu!")
		return {"ok": true, "msg": "📦 ORDER DELIVERED! 💞 OXYTOCIN MODE UNLOCKED! Find it on the main menu."}
	return super.buy_row(kind, id)
