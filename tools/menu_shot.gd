extends SceneTree
## Screenshots the main menu to eyeball the clear-save button.
## Run: DISPLAY=:99 godot --script tools/menu_shot.gd

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
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 60:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/menu_shot.png")
	print("saved /tmp/menu_shot.png")
	quit()
