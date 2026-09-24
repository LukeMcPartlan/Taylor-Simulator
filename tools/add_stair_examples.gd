extends SceneTree
## Builds res://StairExamples.tscn: a TileMapLayer of one-way stair tiles
## (the "Placeholder house tiles" TileSet) placed beneath the map, as an
## example of the one-way stair collision. Main.tscn instances it under
## World (added by hand-edit, 3 lines — never re-save Main.tscn from code).
## Run: godot --headless --script tools/add_stair_examples.gd

const TILESET := "res://placeholder art/Tiles/Placeholder house tiles.tres"
const OUT := "res://StairExamples.tscn"


func _initialize() -> void:
	var ts: TileSet = load(TILESET)
	if ts == null:
		print("FAIL: could not load tileset")
		quit(1)
		return

	var layer := TileMapLayer.new()
	layer.name = "StairExamples"
	layer.tile_set = ts
	# Example stairs beneath the map (basement floor ~y64, killbox y600+):
	# a short up-right flight and an up-left flight at world y=160 (cell y=5).
	var y := 5
	layer.set_cell(Vector2i(-104, y), 0, Vector2i(10, 1))  # stair_up_right_0
	layer.set_cell(Vector2i(-103, y), 0, Vector2i(11, 1))  # stair_up_right_1
	layer.set_cell(Vector2i(-101, y), 0, Vector2i(12, 1))  # stair_up_left_0
	layer.set_cell(Vector2i(-100, y), 0, Vector2i(13, 1))  # stair_up_left_1

	var packed := PackedScene.new()
	var err := packed.pack(layer)
	if err != OK:
		print("FAIL: pack error ", err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT)
	print(("OK saved " + OUT) if err == OK else "FAIL save")
	quit(0 if err == OK else 1)
