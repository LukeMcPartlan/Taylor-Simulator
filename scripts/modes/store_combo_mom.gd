extends ModeStoreBase
## The COMBO-MOM night store: combo extenders and perks bought with Taylor
## Points. Points are the currency AND the score, so every purchase lowers
## your day score — the arcade tradeoff. Open 9pm–11pm in-game (a 30-real-
## second window at 15s per game hour — blink and you'll miss it).


func store_title() -> String:
	return "⚡ NIGHT STORE"


func store_hours_text() -> String:
	return "opens 9pm"


func is_open() -> bool:
	var m := _mode()
	return m != null and m.store_open_now()


func wallet_text() -> String:
	var m := _mode()
	return "Taylor Points: %s" % m.fmt_points(m.day_score) if m != null else ""


func get_rows() -> Array:
	var m := _mode()
	if m == null:
		return []
	var rows: Array = []
	var number := 0
	for item in m.get_shop_items():
		number += 1
		var cost := int(item["cost"])
		var status := String(item["status"])
		rows.append({
			"number": number, "kind": "item", "id": String(item["id"]),
			"name": String(item["name"]), "desc": String(item["desc"]),
			"price": "MAXED" if cost < 0 else "%s PTS" % m.fmt_points(cost),
			"status": status,
			"affordable": cost >= 0 and m.day_score >= cost,
		})
	return rows


func buy_row(_kind: String, id: String) -> Dictionary:
	var m := _mode()
	if m == null:
		return {"ok": false, "msg": "The store blinks out of existence."}
	return m.buy_item(id)


func _mode() -> Node:
	var m := GameState.mode_node()
	if m != null and m.has_method("mode_id") \
			and m.mode_id() == ModeManager.Mode.COMBO_MOM:
		return m
	return null
