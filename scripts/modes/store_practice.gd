extends StoreLaptop
## Taylor's LAPTOP in PRACTICE mode. Same hardware as the other laptops —
## WORK tab turns serotonin into dollars (-10 serotonin, +$10 per verdict,
## a new deranged email every press) — but the shop tab is an AMAZON order
## page selling exactly ONE mode unlock plus the 6-product catalog:
##   1. CLASSIC MODE unlock ($500) — Cortisol Mode, forever.
##   2-7. The same 6 in-run upgrade products Cortisol Mode sells
##      (extra_ball, sponge, pipes, good_drops, green_zone, moon_shoes).
##
## The DOPAMINE MODE unlock is NOT sold here — you buy it from the Cortisol
## store's laptop instead. Buying the classic unlock puts Cortisol Mode on
## the main menu forever (saved in the bank file).

const CLASSIC_PRICE: float = 500.0

## Same ids as StoreCortisol._CORTISOL_IDS (kept in sync manually).
const _CORTISOL_IDS: Array = [
	"extra_ball", "sponge", "pipes", "good_drops", "green_zone", "moon_shoes",
]


func store_title() -> String:
	return "💻 LAPTOP"


func show_title_label() -> bool:
	return false


func _cortisol_defs() -> Array:
	var defs: Array = []
	for pid in _CORTISOL_IDS:
		var d: Dictionary = _UPGRADE_DEFS.def(pid)
		if not d.is_empty():
			defs.append(d)
	return defs


func get_rows() -> Array:
	# Row 1: the one mode unlock. Rows 2-7: the cortisol product catalog
	# (in-run tiers, shared row builder from StoreLaptop).
	var rows: Array = [
		{
			"number": 1, "kind": "unlock", "id": "classic",
			"section": "📦 AMAZON",
			"name": "Cortisol Mode — the full 16-hour day",
			"desc": "Order 😰 Cortisol Mode from Amazon. Same-day delivery straight to the main menu. Forever.",
			"price": "$%d" % int(CLASSIC_PRICE),
			"status": "OWNED" if GameState.is_mode_unlocked(ModeManager.Mode.CLASSIC) else "",
			"affordable": (not GameState.is_mode_unlocked(ModeManager.Mode.CLASSIC)) \
				and GameState.dollars >= CLASSIC_PRICE,
		},
	]
	var m := _mode()
	if m != null:
		rows.append_array(_product_rows(m, _cortisol_defs(), 1))
	return rows


func buy_row(kind: String, id: String) -> Dictionary:
	if kind == "unlock" and id == "classic":
		return _buy_classic_unlock()
	if kind == "upgrade":
		var m := _mode()
		if m == null:
			return {"ok": false, "msg": "The laptop bluescreens."}
		return m.buy_run_upgrade(id)
	return {"ok": false, "msg": "Click a tab, boss."}


func _buy_classic_unlock() -> Dictionary:
	if GameState.is_mode_unlocked(ModeManager.Mode.CLASSIC):
		return {"ok": false, "msg": "Already unlocked!"}
	if GameState.dollars < CLASSIC_PRICE:
		return {"ok": false, "msg": "Need $%d" % int(CLASSIC_PRICE)}
	GameState.add_dollars(-CLASSIC_PRICE)
	GameState.unlock_mode(ModeManager.Mode.CLASSIC)
	GameState.say("TAYLOR", "PACKAGE DELIVERED! 📦 Cortisol Mode is on the main menu!")
	return {"ok": true, "msg": "📦 ORDER DELIVERED! ☀️ CLASSIC MODE UNLOCKED! Find it on the main menu."}


func _mode() -> Node:
	# The base laptop serves no mode by default; this one only practice.
	var m := GameState.mode_node()
	if m != null and m.has_method("mode_id") \
			and m.mode_id() == ModeManager.Mode.PRACTICE:
		return m
	return null


func _build_menu() -> void:
	super._build_menu()
	# The shop tab is an Amazon order page — unlock + the cortisol catalog.
	_tab_amazon_btn.text = "📦 AMAZON"
