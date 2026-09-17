extends Node2D
## Spawns the chore/fun stations and the Luke NPC into Luke's hand-built
## tilemap level (Main.tscn). The level geometry and collision already exist in
## the "Physics" TileMapLayer — this script only places gameplay objects on it.
##
## Station placement (all on walkable ground, west of the tower at x~64):
##   Ground floor (surface y=-96): laundry, dishes, book, baby stations, phone
##   Pond bowl (surface y=64): the basement toilet. The tilemap has no basement
##   interior, so the design was adapted: the leaking toilet flooded the low
##   yard, and Taylor cleans it up there.

const STATION_SCRIPT := preload("res://scripts/station.gd")
const LUKE_SCRIPT := preload("res://scripts/luke.gd")

# id / title / kind (0=chore, 1=fun) / x / floor_y / minigame id
const STATION_DEFS: Array = [
	{"id": "laundry", "title": "Laundry", "kind": 0, "x": -560.0, "floor_y": -96.0, "game": "laundry"},
	{"id": "dishes", "title": "Dishes", "kind": 0, "x": -400.0, "floor_y": -96.0, "game": "dishes"},
	{"id": "book", "title": "Book", "kind": 1, "x": -240.0, "floor_y": -96.0, "game": "book"},
	{"id": "feed_baby", "title": "Feed baby", "kind": 0, "x": -80.0, "floor_y": -96.0, "game": "feed_baby"},
	{"id": "change_baby", "title": "Change baby", "kind": 0, "x": -880.0, "floor_y": -96.0, "game": "change_baby"},
	{"id": "phone", "title": "Phone", "kind": 1, "x": -1200.0, "floor_y": -96.0, "game": "phone"},
	{"id": "basement_toilet", "title": "Basement toilet", "kind": 0, "x": -1760.0, "floor_y": 64.0, "game": "toilet"},
	{"id": "mop_kitchen", "title": "Mop closet", "kind": 0, "x": -1040.0, "floor_y": -96.0, "game": "mop"},
	{"id": "take_out_trash", "title": "Trash bins", "kind": 0, "x": -1350.0, "floor_y": -96.0, "game": "trash"},
	{"id": "microwave", "title": "Microwave", "kind": 0, "x": -1600.0, "floor_y": -96.0, "game": "microwave"},
]

var _effects: Node2D


func _ready() -> void:
	_effects = Node2D.new()
	_effects.name = "Effects"
	add_child(_effects)
	_spawn_stations()
	_spawn_luke()


func spawn_float_text(world_pos: Vector2, text: String, color: Color) -> void:
	## Little rising "+8 serotonin" style popups. Called by stations and Luke.
	var label := Label.new()
	label.text = text
	label.position = world_pos + Vector2(-70, 0)
	label.size = Vector2(140, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = color
	_effects.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 48.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)


func _spawn_stations() -> void:
	for def in STATION_DEFS:
		var station: Station = STATION_SCRIPT.new()
		station.station_id = String(def["id"])
		station.title = String(def["title"])
		station.kind = int(def["kind"])
		station.minigame_id = String(def["game"])
		station.position = Vector2(float(def["x"]), float(def["floor_y"]))
		add_child(station)


func _spawn_luke() -> void:
	var luke: Luke = LUKE_SCRIPT.new()
	luke.position = Vector2(-400.0, -140.0)
	add_child(luke)
