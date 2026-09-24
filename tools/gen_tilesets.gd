extends SceneTree
## Builds the "Placeholder house tiles" TileSet from
##   placeholder art/Tiles/house_tile_sheet.png (+ house_tile_sheet.json)
## Every tile gets a full-square collision polygon on physics layer 0.
## Stair tiles get ONE-WAY collision: jump up through from below, land on top.
## Run: godot --headless --script tools/gen_tilesets.gd

const TILESET_NAME := "Placeholder house tiles"
const SHEET := "res://placeholder art/Tiles/house_tile_sheet.png"
const MANIFEST := "res://placeholder art/Tiles/house_tile_sheet.json"
const OUT := "res://placeholder art/Tiles/Placeholder house tiles.tres"


func _initialize() -> void:
	var img := Image.load_from_file(SHEET)
	if img == null:
		print("FAIL: could not load sheet")
		quit(1)
		return
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var tile_size: int = int(man["tile_size"])

	var ts := TileSet.new()
	ts.resource_name = TILESET_NAME
	ts.tile_size = Vector2i(tile_size, tile_size)
	ts.add_physics_layer(0)

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(tile_size, tile_size)

	var one_way_count := 0
	# NOTE: the source must join the TileSet before tiles are created, or
	# TileData can't see the physics layer.
	ts.add_source(src, 0)
	for tile_name in man["tiles"]:
		var t: Dictionary = man["tiles"][tile_name]
		var at: Array = t["at"]
		var coords := Vector2i(int(at[0]), int(at[1]))
		src.create_tile(coords)
		var td := src.get_tile_data(coords, 0)
		td.add_collision_polygon(0)
		var s := float(tile_size)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(0, 0), Vector2(s, 0), Vector2(s, s), Vector2(0, s),
		]))
		if String(t["collide"]) == "one_way":
			td.set_collision_polygon_one_way(0, 0, true)
			one_way_count += 1

	var err := ResourceSaver.save(ts, OUT)
	print(("%s %s (%d tiles, %d one-way)" % ["OK" if err == OK else "FAIL", OUT, man["tiles"].size(), one_way_count]))
	quit(0 if err == OK else 1)
