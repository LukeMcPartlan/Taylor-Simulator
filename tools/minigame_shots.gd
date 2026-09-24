extends SceneTree
## Screenshots re-skinned minigames to eyeball the placeholder item art.
## Run: DISPLAY=:99 godot --script tools/minigame_shots.gd

var GS = null
var MM = null
var ML = null
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
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")
	ML = root.get_node("/root/MinigameLauncher")
	MM.set_mode(5)  # practice
	GS.set("day_number", 0)
	GS.start_new_day()
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)

	var games := ["change_baby", "trash", "laundry", "toilet", "microwave"]
	var idx := 0
	for g in games:
		ML.open(g, Callable(self, "_noop"))
		# let items spawn/fall a bit
		for i in 90:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("/tmp/mg_shot_%d_%s.png" % [idx, g])
		print("saved mg_shot ", g)
		ML._on_game_finished(true)
		await _frames(10)
		idx += 1
	print("MINIGAME SHOTS DONE")
	quit()


func _noop(_ok: bool, _t: float = 0.0) -> void:
	pass
