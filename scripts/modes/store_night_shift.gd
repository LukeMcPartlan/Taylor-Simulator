extends ModeStoreBase
## The NIGHT-SHIFT night store: permanent buffs (persist across days and runs)
## plus one-day trades (cortisol NOW for a buff until morning). Currency is
## serotonin itself — every purchase drains the meter, so shopping is a genuine
## tradeoff against the day's survival. Open 9pm–11pm in-game.


func store_title() -> String:
	return "🌙 NIGHT STORE"


func store_hours_text() -> String:
	return "opens 9pm"


func is_open() -> bool:
	var m := _mode()
	return m != null and m.store_open_now()


func wallet_text() -> String:
	return "Your serotonin: %d" % int(GameState.serotonin)


func get_rows() -> Array:
	var m := _mode()
	if m == null:
		return []
	var rows: Array = []
	var number := 0
	for def in m.BUFF_DEFS:
		number += 1
		var id := String(def["id"])
		var owned: bool = id in m.owned_buffs
		rows.append({
			"number": number, "kind": "buff", "id": id,
			"name": String(def["label"]), "desc": String(def["desc"]),
			"price": "%d serotonin" % int(def["cost"]),
			"status": "OWNED" if owned else "",
			"affordable": owned or GameState.serotonin >= float(def["cost"]),
		})
	for def in m.TRADE_DEFS:
		number += 1
		var id := String(def["id"])
		var active: bool = m.active_trades.has(id)
		rows.append({
			"number": number, "kind": "trade", "id": id,
			"name": String(def["short"]), "desc": String(def["desc"]),
			"price": "cortisol hit",
			"status": "ACTIVE TODAY" if active else "",
			"affordable": not active,
		})
	return rows


func buy_row(kind: String, id: String) -> Dictionary:
	var m := _mode()
	if m == null:
		return {"ok": false, "msg": "The store blinks out of existence."}
	if kind == "buff":
		return m.buy_buff(id)
	return m.activate_trade(id)


func _mode() -> Node:
	var m := GameState.mode_node()
	if m != null and m.has_method("mode_id") \
			and m.mode_id() == ModeManager.Mode.NIGHT_SHIFT:
		return m
	return null
