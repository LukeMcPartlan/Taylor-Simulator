class_name World
extends Node2D
## Spawns the chore/fun stations, the mode's night store, and the Luke NPC
## into the hand-built tilemap level (Main.tscn). The level geometry and
## collision already exist in the "Physics" TileMapLayer — this script only
## places gameplay objects on it.
##
## Station placement (all on walkable ground, west of the tower at x~64):
##   Ground floor (surface y=-96): laundry, dishes, book, baby stations
##   Pond bowl (surface y=64): the basement toilet. The tilemap has no basement
##   interior, so the design was adapted: the leaking toilet flooded the low
##   yard, and Taylor cleans it up there.
##
## Night stores (one per mode, x=-700 on the ground floor):
##   NIGHT_SHIFT: Taylor's laptop — WORK emails for dollars + AMAZON store,
##     open any time (scripts/modes/store_night_shift.gd).
##   PRACTICE: the same laptop hardware, but the shop tab sells exactly one
##     thing — CLASSIC MODE ($60). WORK tab still turns serotonin to dollars.
##   NIGHT_SHIFT / MELTDOWN / COMBO_MOM / PRACTICE: a walk-up Area2D kiosk
##     script (scripts/modes/store_*.gd), each with its own inventory and
##     currency.
##   DELEGATION: a Station of Kind.STORE (see station.gd) — same spot.
##   CLASSIC: no store. Taylor shops nowhere. She has no time.
##
## Player spawn markers live in the scene (Main.tscn -> World/Spawns): one
## Marker2D per station game plus "default". The killbox (World/Killbox,
## scripts/killbox.gd) respawns Taylor at the nearest one if she falls off
## the map; the day starts her on "default".

const STATION_SCRIPT := preload("res://scripts/station.gd")
const LUKE_SCRIPT := preload("res://scripts/luke.gd")
const CHRIS_SCRIPT := preload("res://scripts/chris.gd")

# id / title / kind (0=chore, 1=fun, 2=store) / x / floor_y / minigame id / work
# (Luke's delegation pace; DELEGATION mode only — his minigame runs at 2x this)
const STATION_DEFS: Array = [
	{"id": "laundry", "title": "Laundry", "kind": 0, "x": -560.0, "floor_y": -96.0, "game": "laundry", "work": 3.0},
	{"id": "dishes", "title": "Dishes", "kind": 0, "x": -400.0, "floor_y": -96.0, "game": "dishes", "work": 2.5},
	{"id": "book", "title": "Book", "kind": 1, "x": -240.0, "floor_y": -96.0, "game": "book", "work": 0.0},
	{"id": "feed_baby", "title": "Feed baby", "kind": 0, "x": -80.0, "floor_y": -96.0, "game": "feed_baby", "work": 4.0},
	{"id": "change_baby", "title": "Change baby", "kind": 0, "x": -880.0, "floor_y": -96.0, "game": "change_baby", "work": 3.0},
	{"id": "basement_toilet", "title": "Basement toilet", "kind": 0, "x": -1760.0, "floor_y": 64.0, "game": "toilet", "work": 5.0},
	{"id": "take_out_trash", "title": "Trash bins", "kind": 0, "x": -1350.0, "floor_y": -96.0, "game": "trash", "work": 2.5},
	{"id": "microwave", "title": "Microwave", "kind": 0, "x": -1600.0, "floor_y": -96.0, "game": "microwave", "work": 3.0},
	{"id": "amazon_boxes", "title": "Amazon boxes", "kind": 0, "x": -750.0, "floor_y": -96.0, "game": "amazon_break", "work": 3.0},
	# DELEGATION mode only: the Night Store as a station (see station.gd).
	{"id": "__store__", "title": "Night Store", "kind": 2, "x": -700.0, "floor_y": -96.0, "work": 0.0},
]

## Modular station defs, appended at runtime via register_station_def().
## Same shape as STATION_DEFS entries. A chore station's "id" must match its
## task def id (see GameState.register_task_def) or E will do nothing.
## Call before the world scene readies (e.g. from a mode node's _init):
##   World.register_station_def({"id": "walk_dog", "title": "Dog leash",
##       "kind": 0, "x": -2000.0, "floor_y": -96.0, "game": "walk_dog",
##       "work": 3.0})
static var extra_station_defs: Array = []


## Adds a station def for this run. Returns false if required fields are
## missing ("id", "title", "kind", "x", "floor_y"); same id twice replaces.
static func register_station_def(def: Dictionary) -> bool:
	for key in ["id", "title", "kind", "x", "floor_y"]:
		if not def.has(key):
			push_error("World.register_station_def: missing '%s'." % key)
			return false
	var id := String(def["id"])
	for i in extra_station_defs.size():
		if String(extra_station_defs[i]["id"]) == id:
			extra_station_defs[i] = def.duplicate()
			return true
	extra_station_defs.append(def.duplicate())
	return true

# Walk-up store kiosk scripts for the modes that use them (DELEGATION uses a
# Station instead; CLASSIC has none).
const STORE_SCRIPTS: Dictionary = {
	1: "res://scripts/modes/store_night_shift.gd",  # Mode.NIGHT_SHIFT
	2: "res://scripts/modes/store_meltdown.gd",     # Mode.MELTDOWN
	4: "res://scripts/modes/store_combo_mom.gd",    # Mode.COMBO_MOM
	5: "res://scripts/modes/store_practice.gd",     # Mode.PRACTICE
}
const STORE_POS := Vector2(-700.0, -96.0)

var _effects: Node2D


func _ready() -> void:
	_effects = Node2D.new()
	_effects.name = "Effects"
	add_child(_effects)
	_hide_spawn_previews()
	_spawn_stations()
	_spawn_store()
	_spawn_luke()
	_spawn_chris()
	spawn_roomba()
	_place_player_at_spawn()


## Spawn markers carry editor-only "Preview" art (a Sprite2D child showing
## what spawns there: station furniture, NPC sprite). The real nodes draw
## their own art at runtime, so the previews hide here to avoid doubles.
func _hide_spawn_previews() -> void:
	var spawns := get_node_or_null("Spawns")
	if spawns == null:
		return
	for marker in spawns.get_children():
		var preview := marker.get_node_or_null("Preview")
		if preview is CanvasItem:
			(preview as CanvasItem).hide()


## Day start: put Taylor on the "default" spawn marker (her scene position
## is the fallback if the marker is missing).
func _place_player_at_spawn() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var marker := get_node_or_null("Spawns/default")
	if player == null or not (marker is Node2D):
		return
	(player as Node2D).global_position = (marker as Node2D).global_position
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO


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


func spawn_done_text(world_pos: Vector2) -> void:
	## "✓ DONE" over the player on a minigame win. Fixed in world space —
	## it fades in place and never follows the player.
	var label := Label.new()
	label.text = "✓ DONE"
	label.position = world_pos + Vector2(-90, 0)
	label.size = Vector2(180, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	_effects.add_child(label)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _spawn_stations() -> void:
	var spawns := get_node_or_null("Spawns")
	for def in STATION_DEFS + extra_station_defs:
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
		station.position = _station_spawn_pos(spawns, def)
		add_child(station)


## Where a station spawns: its Spawns/<id> marker in the scene if Luke moved
## one there, otherwise the def's hardcoded x/floor_y (kept as fallback so
## runtime-registered stations still work without a marker).
func _station_spawn_pos(spawns: Node, def: Dictionary) -> Vector2:
	var fallback := Vector2(float(def["x"]), float(def["floor_y"]))
	if spawns == null:
		return fallback
	var marker := spawns.get_node_or_null(String(def["id"]))
	if marker is Node2D:
		return (marker as Node2D).global_position
	return fallback


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
	# The laptop sits on its Spawns/laptop marker in the scene (draggable in
	# the editor); STORE_POS is the fallback if the marker is missing.
	var marker := get_node_or_null("Spawns/laptop")
	if marker is Node2D:
		store.position = (marker as Node2D).global_position
	else:
		store.position = STORE_POS
	add_child(store)


func _spawn_luke() -> void:
	var luke: Luke = LUKE_SCRIPT.new()
	# Luke starts on his Spawns/luke marker in the scene (draggable in the
	# editor); the old hardcoded spot is the fallback if it's missing.
	var marker := get_node_or_null("Spawns/luke")
	if marker is Node2D:
		luke.position = (marker as Node2D).global_position
	else:
		luke.position = Vector2(-400.0, -110.0)
	add_child(luke)


func _spawn_chris() -> void:
	var chris = CHRIS_SCRIPT.new()
	# Same marker pattern as Luke: Spawns/chris, hardcoded fallback.
	var marker := get_node_or_null("Spawns/chris")
	if marker is Node2D:
		chris.position = (marker as Node2D).global_position
	else:
		chris.position = Vector2(-1700.0, -110.0)
	add_child(chris)


const ROOMBA_SCRIPT: Script = preload("res://scripts/roomba.gd")


func spawn_roomba() -> void:
	## Amazon purchase (night-shift): the little guy patrols and vacuums
	## garbage. Idempotent — buying twice is impossible, but day reloads call
	## this too.
	if get_tree().get_nodes_in_group("roomba").size() > 0:
		return
	# Night-shift Roomba: spawn if any effective tier is owned.
	if GameState.upgrade_tier("roomba") < 1:
		return
	var roomba = ROOMBA_SCRIPT.new()
	roomba.add_to_group("roomba")
	add_child(roomba)
