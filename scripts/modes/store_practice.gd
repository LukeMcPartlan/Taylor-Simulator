extends "res://scripts/modes/store_night_shift.gd"
## Taylor's LAPTOP in PRACTICE mode. Same hardware as night-shift's laptop —
## WORK tab turns serotonin into dollars (-10 serotonin, +$10 per verdict,
## a new deranged email every press) — but the shop tab is an AMAZON order
## page selling exactly ONE thing: CLASSIC MODE, the first real game mode,
## for $60.
##
## Buying it unlocks Classic on the main menu forever (saved in the bank
## file). After that the store just shows OWNED.

## Buying one unlocks that mode on the main menu forever (saved in the bank
## file). After that the store just shows OWNED.

const CLASSIC_PRICE: float = 60.0
const DOPAMINE_PRICE: float = 100.0


func store_title() -> String:
	return "💻 LAPTOP"


func show_title_label() -> bool:
	return false


func _unlock_row(number: int, mode: int, id: String, name: String, desc: String, price: float) -> Dictionary:
	var unlocked := GameState.is_mode_unlocked(mode)
	return {
		"number": number, "kind": "unlock", "id": id,
		"section": "📦 AMAZON",
		"name": name,
		"desc": desc,
		"price": "$%d" % int(price),
		"status": "OWNED" if unlocked else "",
		"affordable": (not unlocked) and GameState.dollars >= price,
	}


func get_rows() -> Array:
	return [
		_unlock_row(1, ModeManager.Mode.CLASSIC, "classic",
			"Cortisol Mode — the full 16-hour day",
			"Order 😰 Cortisol Mode from Amazon. Same-day delivery straight to the main menu. Forever.",
			CLASSIC_PRICE),
		_unlock_row(2, ModeManager.Mode.DOPAMINE, "dopamine",
			"Dopamine Mode — cortisol rules, dopamine drains 5x",
			"Order 📱 Dopamine Mode from Amazon. Same brutal chores, but the phone is life support. Forever.",
			DOPAMINE_PRICE),
	]


func buy_row(kind: String, id: String) -> Dictionary:
	if kind != "unlock":
		return {"ok": false, "msg": "Click a tab, boss."}
	if id == "classic":
		return _buy_unlock(ModeManager.Mode.CLASSIC, "classic", CLASSIC_PRICE,
			"PACKAGE DELIVERED! 📦 Cortisol Mode is on the main menu!",
			"📦 ORDER DELIVERED! ☀️ CLASSIC MODE UNLOCKED! Find it on the main menu.")
	if id == "dopamine":
		return _buy_unlock(ModeManager.Mode.DOPAMINE, "dopamine", DOPAMINE_PRICE,
			"PACKAGE DELIVERED! 📦 Dopamine Mode is on the main menu!",
			"📦 ORDER DELIVERED! 📱 DOPAMINE MODE UNLOCKED! Find it on the main menu.")
	return {"ok": false, "msg": "Click a tab, boss."}


func _buy_unlock(mode: int, id: String, price: float, say_msg: String, ok_msg: String) -> Dictionary:
	if GameState.is_mode_unlocked(mode):
		return {"ok": false, "msg": "Already unlocked!"}
	if GameState.dollars < price:
		return {"ok": false, "msg": "Need $%d" % int(price)}
	GameState.add_dollars(-price)
	GameState.unlock_mode(mode)
	GameState.say("TAYLOR", say_msg)
	return {"ok": true, "msg": ok_msg}


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
