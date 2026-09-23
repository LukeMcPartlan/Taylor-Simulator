extends SceneTree
## Boot sweep: start a fresh day in every mode and run 60 frames to catch
## script errors at boot/day-start.
## Run: godot --headless --script tools/boot_sweep.gd

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
	var GS = root.get_node("/root/GameState")
	var MM = root.get_node("/root/ModeManager")
	var modes := [0, 1, 2, 3, 4, 5]
	var names := ["CLASSIC", "NIGHT_SHIFT", "MELTDOWN", "DELEGATION", "COMBO_MOM", "PRACTICE"]
	var main = null
	for i in modes.size():
		var old_hook = GS.get("mode_hook")
		if old_hook != null:
			GS.remove_child(old_hook)
			old_hook.free()
			GS.set("mode_hook", null)
		MM.set_mode(i)
		var hook = MM.create_mode()
		if hook != null:
			GS.add_child(hook)
			GS.set("mode_hook", hook)
		GS.set("day_number", 0)
		GS.start_new_day()
		if main != null:
			main.queue_free()
			await _frames(5)
		main = load("res://Main.tscn").instantiate()
		root.add_child(main)
		await _frames(60)
		print("BOOT OK: ", names[i])
	print("BOOT SWEEP DONE")
	quit()
