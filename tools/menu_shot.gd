extends SceneTree
## Screenshots the main menu scrolled to the bottom (clear-save button).
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


func _find_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for c in n.get_children():
		var r := _find_scroll(c)
		if r != null:
			return r
	return null


func _run() -> void:
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 30:
		await process_frame
	# Scroll to the very bottom so the wipe button is visible.
	var scroll := _find_scroll(menu)
	if scroll != null:
		var vbar := scroll.get_v_scroll_bar()
		vbar.value = vbar.max_value
		print("scrolled to bottom, has_scroll=", scroll != null)
	else:
		print("NO SCROLL CONTAINER FOUND")
	for i in 30:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/menu_shot.png")
	print("saved /tmp/menu_shot.png")
	quit()
