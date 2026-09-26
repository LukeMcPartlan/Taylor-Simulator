extends "res://scripts/modes/store_night_shift.gd"
## Taylor's LAPTOP in PRACTICE mode. Same hardware as night-shift's laptop —
## WORK tab turns serotonin into dollars (-10 serotonin, +$10 per verdict,
## a new deranged email every press) — but the shop tab is an AMAZON order
## page selling exactly ONE thing: CLASSIC MODE, the first real game mode,
## for $60.
##
## Buying it unlocks Classic on the main menu forever (saved in the bank
## file). After that the store just shows OWNED.

const CLASSIC_PRICE: float = 60.0


func store_title() -> String:
	return "💻 LAPTOP"


func show_title_label() -> bool:
	return false


func get_rows() -> Array:
	var unlocked := GameState.is_mode_unlocked(ModeManager.Mode.CLASSIC)
	return [{
		"number": 1, "kind": "unlock", "id": "classic",
		"section": "📦 AMAZON",
		"name": "Cortisol Mode — the full 16-hour day",
		"desc": "Order 😰 Cortisol Mode from Amazon. Same-day delivery straight to the main menu. Forever.",
		"price": "$%d" % int(CLASSIC_PRICE),
		"status": "OWNED" if unlocked else "",
		"affordable": (not unlocked) and GameState.dollars >= CLASSIC_PRICE,
	}]


func buy_row(kind: String, id: String) -> Dictionary:
	if kind != "unlock" or id != "classic":
		return {"ok": false, "msg": "Click a tab, boss."}
	if GameState.is_mode_unlocked(ModeManager.Mode.CLASSIC):
		return {"ok": false, "msg": "Already unlocked!"}
	if GameState.dollars < CLASSIC_PRICE:
		return {"ok": false, "msg": "Need $%d" % int(CLASSIC_PRICE)}
	GameState.add_dollars(-CLASSIC_PRICE)
	GameState.unlock_mode(ModeManager.Mode.CLASSIC)
	GameState.say("TAYLOR", "PACKAGE DELIVERED! 📦 Cortisol Mode is on the main menu!")
	return {"ok": true, "msg": "📦 ORDER DELIVERED! ☀️ CLASSIC MODE UNLOCKED! Find it on the main menu."}


func _mode() -> Node:
	# The parent laptop only recognizes night-shift; this one only practice.
	var m := GameState.mode_node()
	if m != null and m.has_method("mode_id") \
			and m.mode_id() == ModeManager.Mode.PRACTICE:
		return m
	return null


func _build_menu() -> void:
	super._build_menu()
	# The shop tab is an Amazon order page — the one and only unlock.
	_tab_amazon_btn.text = "📦 AMAZON"
