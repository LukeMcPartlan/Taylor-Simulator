extends SceneTree
## Visual check: boots practice mode and screenshots the station row so the
## new placeholder furniture art can be eyeballed.
## Run: Xvfb :99 & DISPLAY=:99 godot --script tools/art_shots.gd

var GS = null
var MM = null
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
	MM.set_mode(5)  # PRACTICE: every station lit, no tasks needed
	var old_hook = GS.get("mode_hook")
	if old_hook != null:
		GS.remove_child(old_hook)
		old_hook.free()
		GS.set("mode_hook", null)
	var hook = MM.create_mode()
	if hook != null:
		GS.add_child(hook)
		GS.set("mode_hook", hook)
	GS.set("day_number", 0)
	GS.start_new_day()
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)

	var taylor = get_nodes_in_group("player")[0]
	var stops := [150.0, 450.0, 780.0]
	var idx := 0
	for x in stops:
		(taylor as Node2D).global_position = Vector2(x, -60)
		(taylor as CharacterBody2D).velocity = Vector2.ZERO
		await _frames(45)  # let the smoothed camera settle
		var img := root.get_texture().get_image()
		var path := "/tmp/art_shot_%d.png" % idx
		img.save_png(path)
		print("saved ", path)
		idx += 1
	print("ART SHOTS DONE")
	quit()
