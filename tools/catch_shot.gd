extends SceneTree
## Screenshots Diaper Catch mid-game with banana/broccoli/poop falling.

var _booted := false


func _initialize() -> void:
	pass


func _process(_delta: float) -> bool:
	if _booted:
		return false
	_booted = true
	_run()
	return false


func _run() -> void:
	var g = load("res://scripts/minigames/diaper_catch.gd").new()
	g.size = Vector2(960, 720)
	root.add_child(g)
	for i in 5:
		await process_frame
	g.start()
	g._ready_to_draw = true
	# Seed a spread of items: both foods, poop sprite, pee + vomit procedural.
	g._items = [
		{"x": 200.0, "y": 200.0, "kind": "banana"},
		{"x": 380.0, "y": 320.0, "kind": "broccoli"},
		{"x": 560.0, "y": 240.0, "kind": "poop"},
		{"x": 740.0, "y": 360.0, "kind": "pee"},
		{"x": 480.0, "y": 140.0, "kind": "diaper"},
		{"x": 120.0, "y": 420.0, "kind": "vomit"},
	]
	g._spawn_timer = 99.0  # hold spawner off for the shot
	for i in 10:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/catch_shot.png")
	print("saved /tmp/catch_shot.png")
	quit()
