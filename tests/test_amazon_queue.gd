extends SceneTree
## Amazon queued delivery: buying spends dollars and QUEUES the tier — it
## takes effect only when a Box Breaker win delivers it. One win delivers
## every pending order; a loss leaves them queued. Amazon boxes never proc
## randomly and never appear in Serotonin's dawn checklist without an order.

const MODE_CLASSIC := 0
const MODE_PRACTICE := 5

var GS
var MM
var _fails: Array = []
var _checks := 0


func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("PASS: ", name)
	else:
		_fails.append(name)
		print("FAIL: ", name)


func _initialize() -> void:
	_boot.call_deferred()


func _process(_delta: float) -> bool:
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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


func _task_ids() -> Array:
	var ids: Array = []
	for t in GS.get("tasks"):
		ids.append(String(t.get("id", "")))
	return ids


func _task_open(id: String) -> bool:
	for t in GS.get("tasks"):
		if String(t.get("id", "")) == id and not bool(t.get("done", false)):
			return true
	return false


func _find_store(world: Node):
	for n in world.get_children():
		if n.has_method("store_title") and String(n.call("store_title")).contains("LAPTOP"):
			return n
	return null


func _amazon_station():
	for s in get_nodes_in_group("stations"):
		if String(s.get("station_id")) == "amazon_boxes":
			return s
	return null


func _boot() -> void:
	GS = root.get_node("GameState")
	MM = root.get_node("/root/ModeManager")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var world = main.get_node("World")
	_set_mode(MODE_CLASSIC)
	GS.call("start_new_day")
	await _frames(5)
	var m = GS.call("mode_node")
	var store = _find_store(world)

	# 1. Amazon boxes never proc randomly: force 40 proc ticks on a fresh
	#    day with no purchase — the task must never appear.
	for i in 40:
		GS.set("_next_proc_in_s", 0.0)
		await _frames(1)
	_check(not _task_open("amazon_boxes"), "no random amazon procs over 40 forced ticks")
	_check(not ("amazon_boxes" in _task_ids()), "amazon task absent without an order")

	# 2. Buying spends dollars and queues WITHOUT activating.
	GS.set("dollars", 500.0)
	var d0: float = GS.get("dollars")
	var r1: Dictionary = store.buy_row("upgrade", "roomba")
	_check(bool(r1.get("ok", false)), "bought roomba T1")
	_check(float(GS.get("dollars")) < d0, "purchase spent dollars")
	_check(int(m.call("run_tier", "roomba")) == 0, "roomba not active before delivery")
	_check(GS.pending_count("roomba") == 1, "roomba T1 queued")
	_check(int(GS.call("upgrade_tier", "roomba")) == 0, "no effective tier before delivery")

	# 3. The purchase opens the Amazon-box task (the station lights up).
	_check(_task_open("amazon_boxes"), "purchase opened the amazon task")

	# 4. Immediate effects wait for delivery: no Roomba yet.
	_check(get_nodes_in_group("roomba").size() == 0, "no roomba before delivery")

	# 5. A second purchase accumulates into the SAME delivery (one task).
	var r2: Dictionary = store.buy_row("upgrade", "moon_shoes")
	_check(bool(r2.get("ok", false)), "bought moon shoes T1")
	_check(GS.pending_count("moon_shoes") == 1, "moon shoes T1 queued")
	var amazon_tasks := 0
	for t in GS.get("tasks"):
		if String(t.get("id", "")) == "amazon_boxes":
			amazon_tasks += 1
	_check(amazon_tasks == 1, "one amazon task covers both orders")

	# 6. Pending tiers count toward progression: the shelf offers T2 next
	#    and flags what's on the truck.
	var rows: Array = store.get_rows()
	var shoe_row: Dictionary = {}
	for row in rows:
		if String(row.get("id", "")) == "moon_shoes":
			shoe_row = row
	_check(String(shoe_row.get("status", "")).contains("on the way"), "shelf flags the pending order")
	_check(String(shoe_row.get("name", "")).contains("T1/3"), "shelf offers T2 next (not T1 again)")

	# 7. One Box Breaker win delivers EVERYTHING pending.
	var station = _amazon_station()
	_check(station != null, "amazon station exists")
	station.call("_on_minigame_done", true, 1.0)
	await _frames(2)
	_check(not _task_open("amazon_boxes"), "amazon task done after the win")
	_check(int(m.call("run_tier", "roomba")) == 1, "roomba T1 active after delivery")
	_check(int(m.call("run_tier", "moon_shoes")) == 1, "moon shoes T1 active after delivery")
	_check(GS.pending_count("roomba") == 0, "queue emptied by the win")
	_check(get_nodes_in_group("roomba").size() == 1, "roomba spawned on delivery")

	# 8. A loss leaves orders pending (task stays open, nothing activates).
	var r3: Dictionary = store.buy_row("upgrade", "pipes")
	_check(bool(r3.get("ok", false)), "bought pipes T1")
	_check(_task_open("amazon_boxes"), "amazon task re-opened by the new order")
	station.call("_on_minigame_done", false, 1.0)
	await _frames(2)
	_check(GS.pending_count("pipes") == 1, "loss keeps the order queued")
	_check(int(m.call("run_tier", "pipes")) == 0, "loss activates nothing")
	_check(_task_open("amazon_boxes"), "loss keeps the task open")

	# 9. Duplicate ordering blocked: T1 pending -> T2 -> T3 -> maxed.
	GS.set("dollars", 500.0)
	_check(bool(store.buy_row("upgrade", "sponge").get("ok", false)), "sponge T1 ordered")
	_check(bool(store.buy_row("upgrade", "sponge").get("ok", false)), "sponge T2 ordered")
	_check(bool(store.buy_row("upgrade", "sponge").get("ok", false)), "sponge T3 ordered")
	_check(GS.pending_count("sponge") == 3, "three sponge tiers queued")
	_check(not bool(store.buy_row("upgrade", "sponge").get("ok", false)), "fourth sponge order refused")

	# 10. Serotonin dawn checklist never creates Amazon boxes without an order.
	_set_mode(MODE_PRACTICE)
	GS.call("start_new_day")
	await _frames(5)
	_check(not ("amazon_boxes" in _task_ids()), "serotonin dawn: no amazon task without an order")
	var all_chores_open := true
	for def in GS.get("task_defs"):
		var did := String(def.get("id", ""))
		if did != "amazon_boxes" and not (did in _task_ids()):
			all_chores_open = false
	_check(all_chores_open, "serotonin dawn: every other chore def opened")

	print("----")
	print("checks: %d  failures: %d" % [_checks, _fails.size()])
	if _fails.is_empty():
		print("ALL GREEN")
	else:
		print("FAILURES: ", _fails)
	quit(1 if not _fails.is_empty() else 0)
