extends SceneTree
## Full visual verification pass for the follow-up items:
##  1. main menu cards: product counts + bird indicators
##  2. dirty toilet (task open) then clean toilet (task done)
##  3. small laptop station
##  4. example stairs beneath the map
##  5. parallax at several camera heights
## Run: Xvfb :99 & DISPLAY=:99 godot --script tools/verify_shots.gd

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


func _shot(path: String) -> void:
	await _frames(30)
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path)


func _move_taylor_to(pos: Vector2) -> void:
	var taylor = get_nodes_in_group("player")[0]
	(taylor as Node2D).global_position = pos
	(taylor as CharacterBody2D).velocity = Vector2.ZERO


func _run() -> void:
	GS = root.get_node("/root/GameState")
	MM = root.get_node("/root/ModeManager")

	# --- 1. main menu ------------------------------------------------------
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _shot("/tmp/v_menu.png")
	root.remove_child(menu)
	menu.queue_free()
	await _frames(10)

	# --- practice day: all tasks open -> toilet starts dirty ----------------
	MM.set_mode(5)
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

	# --- 2. dirty toilet -----------------------------------------------------
	_move_taylor_to(Vector2(371, -60))
	await _shot("/tmp/v_toilet_dirty.png")
	# complete the task -> clean
	GS.call("complete_task", "basement_toilet", "taylor")
	await _shot("/tmp/v_toilet_clean.png")

	# --- 3. laptop ------------------------------------------------------------
	_move_taylor_to(Vector2(687, -400))
	await _shot("/tmp/v_laptop.png")

	# --- 4. example stairs beneath the map --------------------------------------
	_move_taylor_to(Vector2(-3264, 60))
	await _shot("/tmp/v_stairs.png")

	# --- 5. parallax at several heights ------------------------------------------
	_move_taylor_to(Vector2(150, -60))
	await _shot("/tmp/v_parallax_low.png")
	_move_taylor_to(Vector2(150, -500))
	await _shot("/tmp/v_parallax_high.png")
	_move_taylor_to(Vector2(150, -1000))
	await _shot("/tmp/v_parallax_sky.png")

	print("VERIFY SHOTS DONE")
	quit()
