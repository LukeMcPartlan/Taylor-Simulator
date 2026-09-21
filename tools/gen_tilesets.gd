extends SceneTree
## Builds TileSet .tres resources for the placeholder tile sheets.
## Run: godot --headless --script tools/gen_tilesets.gd

func _make(sheet: String, out: String) -> void:
	var img := Image.load_from_file("res://placeholder art/Tiles/" + sheet)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(16, 16)
	var cols := int(img.get_width() / 16)
	var rows := int(img.get_height() / 16)
	for y in rows:
		for x in cols:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src)
	var err := ResourceSaver.save(ts, "res://placeholder art/Tiles/" + out)
	print(("OK " if err == OK else "FAIL ") + out + " (%dx%d tiles)" % [cols, rows])


func _initialize() -> void:
	_make("house_tiles.png", "house_tiles.tres")
	_make("tree_tiles.png", "tree_tiles.tres")
	quit()
