extends SceneTree
## Visual check: boots practice mode, completes one task via the API, then
## screenshots the HUD so the new checkbox task rows can be eyeballed.
## Run: Xvfb :99 & DISPLAY=:99 godot --script tools/checklist_shot.gd

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
	MM.set_mode(5)  # PRACTICE
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

	# Complete one ordinary chore so a DONE row is visible.
	var done_id := ""
	for t in GS.tasks:
		var id: String = t.get("id", "")
		if not bool(t.get("done", false)) and not bool(t.get("delegated", false)):
			done_id = id
			break
	if done_id != "":
		GS.complete_task(done_id)
		print("completed task: ", done_id)
	await _frames(10)

	var img := root.get_texture().get_image()
	var path := "/tmp/checklist_shot.png"
	img.save_png(path)
	print("saved ", path)
	print("CHECKLIST SHOT DONE")
	quit()
