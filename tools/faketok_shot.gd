extends SceneTree
## Visual check: opens the FakeTok minigame directly and screenshots the
## gameplay view and the comments view.
## Run: Xvfb :99 & DISPLAY=:99 godot --script tools/faketok_shot.gd

var _booted := false


func _initialize() -> void:
	pass


func _process(_delta: float) -> bool:
	if _booted:
		return false
	_booted = true
	_run()
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game = load("res://scripts/minigames/phone_swipe.gd").new()
	game.size = Vector2(700, 560)
	root.add_child(game)
	game.start()
	game._ready_to_draw = true
	await _frames(5)
	# Force a DOWN prompt and a mid-deck display for the gameplay shot.
	game.test_set_prompt(KEY_DOWN)
	game.set("_display_index", 2)
	await _frames(3)
	var img := root.get_texture().get_image()
	img.save_png("/tmp/faketok_game.png")
	print("saved /tmp/faketok_game.png")
	# Open the comments and scroll a little for the comments shot.
	game.test_set_prompt(KEY_LEFT)
	game.test_press(KEY_LEFT)
	await _frames(3)
	img = root.get_texture().get_image()
	img.save_png("/tmp/faketok_comments.png")
	print("saved /tmp/faketok_comments.png")
	print("FAKETOK SHOTS DONE")
	quit()
