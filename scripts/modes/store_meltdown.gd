extends ModeStoreBase
## The MELTDOWN night store: 5 permanent coping mechanisms (bought with
## serotonin, run-long — no save file in this mode) plus 3 instant venting
## trades with cooldowns. Open 9pm–11pm in-game.


func store_title() -> String:
	return "😱 NIGHT STORE"


func store_hours_text() -> String:
	return "opens 9pm"


func is_open() -> bool:
	var m := _mode()
	return m != null and m.store_open_now()


func wallet_text() -> String:
	return "Your serotonin: %d · Sanity: %d/3" % [
		int(GameState.serotonin), _mode().sanity_lives if _mode() != null else 3]


func get_rows() -> Array:
	var m := _mode()
	if m == null:
		return []
	var rows: Array = []
	var number := 0
	for def in m.COPING_DEFS:
		number += 1
		var id := String(def["id"])
		var owned: bool = m.coping_owned.has(id)
		rows.append({
			"number": number, "kind": "coping", "id": id,
			"name": String(def["name"]), "desc": String(def["blurb"]),
			"price": "%d serotonin" % int(def["cost"]),
			"status": "OWNED" if owned else "",
			"affordable": owned or GameState.serotonin >= float(def["cost"]),
		})
	for def in m.VENT_DEFS:
		number += 1
		var id := String(def["id"])
		var cd: float = float(m.vent_cooldowns.get(id, 0.0))
		rows.append({
			"number": number, "kind": "vent", "id": id,
			"name": String(def["name"]),
			"desc": "-%d cortisol right now" % int(def["cortisol_dump"]),
			"price": "%d serotonin" % int(def["serotonin_cost"]),
			"status": "%ds cooldown" % int(ceil(cd)) if cd > 0.0 else "",
			"affordable": cd <= 0.0 and GameState.serotonin >= float(def["serotonin_cost"]),
		})
	return rows


func buy_row(kind: String, id: String) -> Dictionary:
	var m := _mode()
	if m == null:
		return {"ok": false, "msg": "The store blinks out of existence."}
	if kind == "coping":
		return m.buy_coping(id)
	return m.vent(id)


func _mode() -> Node:
	var m := GameState.mode_node()
	if m != null and m.has_method("mode_id") \
			and m.mode_id() == ModeManager.Mode.MELTDOWN:
		return m
	return null
