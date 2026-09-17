extends Node2D
## Spawns the chore/fun stations, the mode's night store, and the Luke NPC
## into the hand-built tilemap level (Main.tscn). The level geometry and
## collision already exist in the "Physics" TileMapLayer — this script only
## places gameplay objects on it.
##
## Station placement (all on walkable ground, west of the tower at x~64):
##   Ground floor (surface y=-96): laundry, dishes, book, baby stations, phone
##   Pond bowl (surface y=64): the basement toilet. The tilemap has no basement
##   interior, so the design was adapted: the leaking toilet flooded the low
##   yard, and Taylor cleans it up there.
##
## Night stores (one per mode, x=-700 on the ground floor, open 9pm-11pm):
##   NIGHT_SHIFT / MELTDOWN / COMBO_MOM: a walk-up Area2D kiosk script
##     (scripts/modes/store_*.gd), each with its own inventory and currency.
##   DELEGATION: a Station of Kind.STORE (see station.gd) — same spot.
##   CLASSIC: no store. Taylor shops nowhere. She has no time.

const STATION_SCRIPT := preload("res://scripts/station.gd")
const LUKE_SCRIPT := preload("res://scripts/luke.gd")

# id / title / kind (0=chore, 1=fun, 2=store) / x / floor_y / minigame id / work
# (Luke's delegation pace; DELEGATION mode only — his minigame runs at 2x this)
const STATION_DEFS: Array = [
	{"id": "laundry", "title": "Laundry", "kind": 0, "x": -560.0, "floor_y": -96.0, "game": "laundry", "work": 3.0},
	{"id": "dishes", "title": "Dishes", "kind": 0, "x": -400.0, "floor_y": -96.0, "game": "dishes", "work": 2.5},
	{"id": "book", "title": "Book", "kind": 1, "x": -240.0, "floor_y": -96.0, "game": "book", "work": 0.0},
	{"id": "feed_baby", "title": "Feed baby", "kind": 0, "x": -80.0, "floor_y": -96.0, "game": "feed_baby", "work": 4.0},
	{"id": "change_baby", "title": "Change baby", "kind": 0, "x": -880.0, "floor_y": -96.0, "game": "change_baby", "work": 3.0},
	{"id": "phone", "title": "Phone", "kind": 1, "x": -1200.0, "floor_y": -96.0, "game": "phone", "work": 0.0},
	{"id": "basement_toilet", "title": "Basement toilet", "kind": 0, "x": -1760.0, "floor_y": 64.0, "game": "toilet", "work": 5.0},
	{"id": "mop_kitchen", "title": "Mop closet", "kind": 0, "x": -1040.0, "floor_y": -96.0, "game": "mop", "work": 3.0},
	{"id": "take_out_trash", "title": "Trash bins", "kind": 0, "x": -1350.0, "floor_y": -96.0, "game": "trash", "work": 2.5},
	{"id": "microwave", "title": "Microwave", "kind": 0, "x": -1600.0, "floor_y": -96.0, "game": "microwave", "work": 3.0},
	# DELEGATION mode only: the Night Store as a station (see station.gd).
	{"id": "__store__", "title": "Night Store", "kind": 2, "x": -700.0, "floor_y": -96.0, "work": 0.0},
]

# Walk-up store kiosk scripts for the modes that use them (DELEGATION uses a
# Station instead; CLASSIC has none).
const STORE_SCRIPTS: Dictionary = {
	1: "res://scripts/modes/store_night_shift.gd",  # Mode.NIGHT_SHIFT
	2: "res://scripts/modes/store_meltdown.gd",     # Mode.MELTDOWN
	4: "res://scripts/modes/store_combo_mom.gd",    # Mode.COMBO_MOM
}
const STORE_POS := Vector2(-700.0, -96.0)

var _effects: Node2D


func _ready() -> void:
	_effects = Node2D.new()
	_effects.name = "Effects"
	add_child(_effects)
	_spawn_stations()
	_spawn_store()
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
		var kind: int = int(def["kind"])
		# The __store__ station def only exists for DELEGATION mode.
		if kind == 2 and ModeManager.current_mode != ModeManager.Mode.DELEGATION:
			continue
		var station: Station = STATION_SCRIPT.new()
		station.station_id = String(def["id"])
		station.title = String(def["title"])
		station.kind = kind
		station.minigame_id = String(def.get("game", ""))
		station.work_seconds = float(def.get("work", 3.0))
		station.position = Vector2(float(def["x"]), float(def["floor_y"]))
		add_child(station)


func _spawn_store() -> void:
	# Walk-up kiosk stores for NIGHT_SHIFT / MELTDOWN / COMBO_MOM.
	var path: String = String(STORE_SCRIPTS.get(ModeManager.current_mode, ""))
	if path == "":
		return
	var script: Script = load(path)
	if script == null:
		push_error("world: could not load store script " + path)
		return
	var store: Area2D = script.new()
	store.position = STORE_POS
	add_child(store)


func _spawn_luke() -> void:
	var luke: Luke = LUKE_SCRIPT.new()
	luke.position = Vector2(-400.0, -140.0)
	add_child(luke)
