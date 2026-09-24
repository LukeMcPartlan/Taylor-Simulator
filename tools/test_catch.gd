extends SceneTree
## Functional check: Diaper Catch with banana/broccoli goods + poop sprite.

var _booted := false
var _results: Array = []


func _initialize() -> void:
	pass


func _process(_delta: float) -> bool:
	if _booted:
		return false
	_booted = true
	_run()
	return false


func _check(cond: bool, label: String) -> void:
	_results.append(("PASS " if cond else "FAIL ") + label)


func _make_game():
	var g = load("res://scripts/minigames/diaper_catch.gd").new()
	g.size = Vector2(960, 720)
	root.add_child(g)
	return g


func _run() -> void:
	var g = load("res://scripts/minigames/diaper_catch.gd").new()
	_check(g.GOODS.has("banana") and g.GOODS.has("broccoli"), "banana+broccoli in GOODS")
	_check(g.GOODS.size() == 6, "6 goods total")
	_check(g.GOOD_TEX.has("banana") and g.GOOD_TEX.has("broccoli"), "food textures wired")
	_check(g.POOP_TEX != null, "poop sprite loaded")
	g.free()

	# Win path: catch all six, game ends with success=true.
	var g1 = _make_game()
	var won := [false]
	g1.finished.connect(func(success: bool) -> void: won[0] = success)
	for i in 5:
		await process_frame
	g1.start()
	for k in ["diaper", "powder", "wipe", "clothes"]:
		g1._catch_item(k, Vector2.ZERO)
	_check(not bool(g1.get("_over")), "no win with only 4/6 goods")
	g1._catch_item("banana", Vector2.ZERO)
	g1._catch_item("broccoli", Vector2.ZERO)
	_check(bool(g1.get("_over")) and won[0], "win after all 6 goods")
	g1.free()

	# Gross poop knocks a collected item back off.
	var g2 = _make_game()
	for i in 5:
		await process_frame
	g2.start()
	g2._catch_item("diaper", Vector2.ZERO)
	g2._catch_item("banana", Vector2.ZERO)
	g2._catch_item("poop", Vector2(100, 100))
	var have: Dictionary = g2.get("_have")
	var owned := 0
	for k in have:
		if bool(have[k]):
			owned += 1
	_check(owned == 1, "poop knocks one item off (2->1)")
	_check(not bool(g2.get("_over")), "game continues after gross catch")
	g2.free()

	for r in _results:
		print(r)
	quit()
