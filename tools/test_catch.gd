extends SceneTree
## Functional check: Diaper Catch — 4 goods, piss/shit/vomit sprite gross-outs.

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
	_check(g.GOODS.size() == 4, "4 goods, no banana/broccoli")
	_check(not g.GOODS.has("banana") and not g.GOODS.has("broccoli"),
		"banana/broccoli references removed")
	_check(g.GROSS_TEX.has("poop") and g.GROSS_TEX.has("pee") and g.GROSS_TEX.has("vomit"),
		"piss/shit/vomit gross sprites wired")
	g.free()

	# Win path: catch all four goods.
	var g1 = _make_game()
	var won := [false]
	g1.finished.connect(func(success: bool) -> void: won[0] = success)
	for i in 5:
		await process_frame
	g1.start()
	g1.test_catch_all_goods()
	_check(bool(g1.get("_over")) and won[0], "win after all 4 goods")
	g1.free()

	# Gross-outs knock a collected item back off.
	var g2 = _make_game()
	for i in 5:
		await process_frame
	g2.start()
	g2.test_catch_diaper()
	g2._catch_item("pee", Vector2(100, 100))
	var have: Dictionary = g2.get("_have")
	_check(not bool(have["diaper"]), "pee knocks diaper off")
	g2._catch_item("diaper", Vector2.ZERO)
	g2._catch_item("vomit", Vector2(100, 100))
	have = g2.get("_have")
	_check(not bool(have["diaper"]), "vomit knocks diaper off")
	_check(not bool(g2.get("_over")), "game continues after gross catches")
	g2.free()

	for r in _results:
		print(r)
	quit()
